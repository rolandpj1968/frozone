# Box-first C++ backend — Cpp string generators.
#
# Pure-function counterpart to the Emitter writers. Every method here
# produces a cpp string for an AST node — never touches a buffer or
# emits anything. Writers (in expr_emitter, class_emitter, etc.) call
# `cpp.from_X(node, locals)` for the inline expression bits and use
# their own `emit.line` / `emit.indented` to commit multi-line
# structures.
#
# Cpp is a class (not a module) because compilation context
# (user_classes / user_constants registries) is encapsulated as
# instance state — set once at compilation start, doesn't change. The
# Emitter holds the Cpp instance; writers reach it via `emit.cpp`.
#
# Per-call context (locals scope) stays as method args — it changes
# constantly as we walk into nested scopes.

require_relative 'runtime/universe'

module Frozone
  module Compiler
    module Backend
      module CppBox
        class Cpp
          # Raised at emission time when we encounter a Ruby pattern we
          # don't yet handle, OR a closed-world violation (constant we
          # can't statically resolve). Eager fail: better to halt the
          # build with a precise message than to silently emit nil and
          # produce a wrong binary.
          class EmissionError < StandardError; end
          # Ruby operator → C++ vtable method name. Box-first can't use
          # operator overloading because every value is a pointer
          # (`a + b` would mean pointer arithmetic), so we route through
          # named virtuals on BasicObject's derived classes.
          OP_NAMES = {
            # Arithmetic
            :+   => "m_plus",  :-   => "m_minus",
            :*   => "m_mul",   :**  => "m_pow",
            :/   => "m_div",   :%   => "m_mod",
            # Comparison
            :<   => "m_lt",    :>   => "m_gt",
            :<=  => "m_le",    :>=  => "m_ge",
            :==  => "m_eq_q",  :!=  => "m_ne_q",
            :"<=>" => "m_spaceship",
            :=== => "m_case_eq",
            :=~  => "m_match",
            :!~  => "m_no_match",
            # Bitwise / shift
            :&   => "m_bit_and",
            :|   => "m_bit_or",
            :^   => "m_bit_xor",
            :~   => "m_bit_not",
            :<<  => "m_lshift",
            :>>  => "m_rshift",
            # Unary
            :!   => "m_not",
            :"-@" => "m_neg",
            :"+@" => "m_pos",
            # Indexing
            :[]  => "m_aref",
            :[]= => "m_aset",
          }.freeze

          # Ruby method name → C++ identifier. Operators go through
          # OP_NAMES; non-identifier suffixes (`?`, `!`, `=`) get
          # mangled to `_q`, `_b`, `_set` respectively.
          def self.method_name(ruby_name)
            return OP_NAMES[ruby_name] if OP_NAMES.key?(ruby_name)
            s = ruby_name.to_s
            s = s.sub(/\?$/, '_q').sub(/!$/, '_b').sub(/=$/, '_set')
            "m_#{s}"
          end

          # Nodes that produce a value usable in expression position.
          # Statement-only nodes (Return, Sequence, While) don't get
          # wrapped in implicit-return; they handle their own control
          # flow or have void value.
          # Ast::If and Ast::Case ARE expression-valid (Ruby's if/case
          # return the taken branch's value) — emitted as ternary or
          # lambda+early-return in expression position, multi-line in
          # statement position.
          def self.expression_node?(node)
            case node
            when Ast::Return, Ast::Sequence, Ast::While then false
            else true
            end
          end

          attr_reader :user_classes, :user_constants

          def initialize(user_classes:, user_constants:)
            @user_classes = user_classes
            @user_constants = user_constants
          end

          # Top-level dispatch — turns an AST node into a cpp expression
          # string. Pure: no side effects. Recursive into sub-expressions.
          def from_expr(node, locals)
            case node
            when Ast::IntegerLiteral then "(new Integer(#{node.value.raw}LL))"
            when Ast::FloatLiteral   then "(new Float(#{node.value}))"
            when Ast::NilLiteral     then "nil_instance()"
            when Ast::TrueLiteral    then "true_instance()"
            when Ast::FalseLiteral   then "false_instance()"
            when Ast::SelfLiteral    then "this"
            when Ast::SymbolLiteral  then from_symbol_literal(node)
            when Ast::StringLiteral  then from_string_literal(node)
            when Ast::ArrayLiteral   then from_array_literal(node, locals)
            when Ast::HashLiteral    then from_hash_literal(node, locals)
            when Ast::LocalVariableRead then node.name.to_s
            when Ast::ConstantRead then from_constant_read(node)
            when Ast::ConstantPath then from_constant_path(node)
            when Ast::InstanceVariableRead then "this->iv_#{node.name.to_s.delete_prefix('@')}"
            when Ast::InstanceVariableWrite
              rhs = from_expr(node.value_node, locals)
              "(this->iv_#{node.name.to_s.delete_prefix('@')} = #{rhs})"
            when Ast::LocalVariableWrite
              rhs = from_expr(node.value_node, locals)
              if locals.include?(node.name.to_s)
                "(#{node.name} = #{rhs})"
              else
                # Local-decl in expr position needs scope hoisting
                # (declare in outer scope, assign here). Not implemented.
                raise EmissionError,
                  "LocalVariableWrite in expression position requires scope-hoisting (var: #{node.name}) — not implemented"
              end
            when Ast::MethodCall then from_method_call(node, locals)
            when Ast::AttributeWrite then from_attribute_write(node, locals)
            when Ast::And then from_and(node, locals)
            when Ast::Or then from_or(node, locals)
            when Ast::If then from_if(node, locals)
            when Ast::Case then from_case(node, locals)
            when Ast::Yield then from_yield(node, locals)
            when Ast::Sequence
              # `(a)` and `(a, b, c)` both work as comma-operator —
              # value is the last subexpression.
              "(#{node.nodes.map { |n| from_expr(n, locals) }.join(", ")})"
            else
              raise EmissionError, "from_expr: unhandled AST node #{node.class.name}"
            end
          end

          # Universal call protocol: every Ruby method call is
          #   recv->m_X(args_array, kwargs_hash_or_nullptr, block_or_nullptr)
          # where args_array is `(new Array({a, b, ...}))`. The called
          # method's body unpacks args to its declared params.
          # Specializations like `m_X_1(arg)` are an optimisation layer
          # we may add later (per call-site mangling); for now everything
          # is generic.
          def from_method_call(node, locals)
            recv = node.receiver_node
            name = node.name
            arg_nodes = node.arg_nodes || []

            # ClassName.new(args) or Foo::Bar.new(args) → direct
            # instantiation. Bypasses the vtable. Wrap in parens so
            # trailing -> on the result binds tighter than `new`.
            if name == :new && (recv.is_a?(Ast::ConstantRead) || recv.is_a?(Ast::ConstantPath))
              cls_name = recv.is_a?(Ast::ConstantRead) ? recv.name.to_s : path_to_cpp_name(recv)
              if instantiable_class?(cls_name.to_sym)
                args = arg_nodes.map { |a| from_arg(a, locals) }
                return "(new #{cls_name}(#{args.join(", ")}))"
              end
            end

            # Block-bearing call site (other than the .times for-loop
            # special-case which write_stmt handles): wrap the block as
            # a Proc and pass as the third call-protocol arg.
            block_arg = if node.block_node && !(name == :times && recv)
                          from_block_as_proc(node.block_node, locals)
                        else
                          "nullptr"
                        end
            args_array = build_args_array(arg_nodes, locals)
            kwargs_arg = "nullptr"  # kwargs deferred

            if recv
              "#{from_expr(recv, locals)}->#{Cpp.method_name(name)}(#{args_array}, #{kwargs_arg}, #{block_arg})"
            elsif name == :puts
              # ruby_puts returns void; Ruby's puts returns nil — comma
              # operator gives the right type for expression contexts.
              # ruby_puts is a runtime free function (NOT a vtable
              # method) so it bypasses the universal call protocol.
              args = arg_nodes.map { |a| from_arg(a, locals) }
              "(ruby_puts(#{args.join(", ")}), nil_instance())"
            else
              "this->#{Cpp.method_name(name)}(#{args_array}, #{kwargs_arg}, #{block_arg})"
            end
          end

          # Build the args Array for a call. Cases:
          # - Empty: (new Array({}))
          # - All literal args: (new Array({a, b, ...}))
          # - Single splat: pass the splat's value directly (it's
          #   already an Array — no wrapping)
          # - Mixed splat+literal: defer (would need flattening logic).
          def build_args_array(arg_nodes, locals)
            if arg_nodes.length == 1 && arg_nodes[0].is_a?(Ast::SplatArg)
              # The splat's value is statically a BasicObject* (locals
              # are all BasicObject*); cast to Array* for the call.
              # Real Ruby would call to_a on it; static_cast assumes
              # the value IS an Array, which is the common case.
              "static_cast<Array*>(#{from_expr(arg_nodes[0].value_node, locals)})"
            elsif arg_nodes.any? { |a| a.is_a?(Ast::SplatArg) }
              raise EmissionError, "mixed positional + splat args not yet supported"
            else
              args = arg_nodes.map { |a| from_expr(a, locals) }
              "(new Array({#{args.join(", ")}}))"
            end
          end

          # Single arg in a MethodCall.arg_nodes list. Splat-args
          # (`foo(*arr)`) emit the splat's value directly — the called
          # method's rest_param receives the Array as-is. No flattening
          # in our model: `foo(1, *arr, 5)` would pass them as 3
          # positional args, NOT as the Ruby-semantic flattened list
          # — defer the flattening case until needed.
          def from_arg(node, locals)
            return from_expr(node.value_node, locals) if node.is_a?(Ast::SplatArg)
            from_expr(node, locals)
          end

          # `Ast::Yield` → call into the implicit `_block` Proc* that
          # MethodEmitter inserts when a body contains yield.
          # Universal call protocol: m_call(args, kwargs, block).
          # Multi-arg yield works since args is an Array.
          def from_yield(node, locals)
            args = (node.arg_nodes || []).map { |a| from_expr(a, locals) }
            "_block->m_call((new Array({#{args.join(", ")}})), nullptr, nullptr)"
          end

          # Wrap a block AST node as `(new Proc([&](BasicObject* arg) ->
          # BasicObject* { ... }))`. Captures by reference so the closure
          # sees enclosing locals. Block param `|x|` becomes a local
          # binding from `arg`. Multi-statement bodies emit each as a
          # statement except the last which becomes the lambda's return.
          # Statement-only nodes (If-as-stmt, Return, etc.) inside a
          # block body are not yet supported — defer if hit.
          def from_block_as_proc(block_node, locals)
            param = (block_node.required_params || []).first
            block_locals = locals.dup
            block_locals << param.to_s if param

            body = block_node.body
            stmts = body.is_a?(Ast::Sequence) ? body.nodes : (body ? [body] : [])

            parts = []
            parts << "BasicObject* #{param} = arg;" if param
            stmts.each_with_index do |n, i|
              s = from_expr(n, block_locals)
              if i == stmts.length - 1
                parts << "return #{s};"
              else
                parts << "#{s};"
              end
            end
            parts << "return nil_instance();" if stmts.empty?

            "(new Proc([&](BasicObject* arg) -> BasicObject* { #{parts.join(' ')} }))"
          end

          # `arr[k] = v` parses as AttributeWrite(name=:[]=, receiver,
          # arg_nodes=[k, v]). Emit as a vtable call to m_aset via
          # the universal protocol.
          def from_attribute_write(node, locals)
            recv_s = from_expr(node.receiver_node, locals)
            args = (node.arg_nodes || []).map { |a| from_expr(a, locals) }
            args_array = "(new Array({#{args.join(", ")}}))"
            "#{recv_s}->#{Cpp.method_name(node.name)}(#{args_array}, nullptr, nullptr)"
          end

          # Ruby's `&&` returns the last truthy value or the first falsy.
          # Lambda-wrap to evaluate left at most once.
          def from_and(node, locals)
            l = from_expr(node.left_node, locals)
            r = from_expr(node.right_node, locals)
            "([&]() -> BasicObject* { auto* _l = #{l}; return truthy(_l) ? (#{r}) : _l; }())"
          end

          # Ruby's `||` returns the first truthy value, else the last.
          def from_or(node, locals)
            l = from_expr(node.left_node, locals)
            r = from_expr(node.right_node, locals)
            "([&]() -> BasicObject* { auto* _l = #{l}; return truthy(_l) ? _l : (#{r}); }())"
          end

          # If-as-expression — `cond ? a : b` and `if cond; a; else; b; end`
          # are the same Ast::If. Plain C++ ternary (short-circuits, no
          # lambda needed). Multi-statement bodies become Ast::Sequence
          # which from_expr emits as comma-operator.
          # Missing else_node → nil (Ruby semantics).
          def from_if(node, locals)
            cond = from_expr(node.pred_node, locals)
            t = node.then_node ? from_expr(node.then_node, locals) : "nil_instance()"
            e = node.else_node ? from_expr(node.else_node, locals) : "nil_instance()"
            "(truthy(#{cond}) ? (#{t}) : (#{e}))"
          end

          # Case-as-expression — lambda + early-return form. Multi-statement
          # bodies become Sequence (comma operator). Without subject_node,
          # conditions are truthy-tested directly.
          def from_case(node, locals)
            buf = +"([&]() -> BasicObject* { "
            if node.subject_node
              buf << "auto* _subj = #{from_expr(node.subject_node, locals)}; "
            end
            node.whens.each do |w|
              cond_strs = w.condition_nodes.map { |c|
                c_s = from_expr(c, locals)
                node.subject_node ? "truthy(#{c_s}->m_case_eq((new Array({_subj})), nullptr, nullptr))" : "truthy(#{c_s})"
              }
              buf << "if (#{cond_strs.join(" || ")}) return #{from_expr(w.body_node, locals)}; "
            end
            buf << "return #{node.else_node ? from_expr(node.else_node, locals) : "nil_instance()"}; }())"
            buf
          end

          def from_array_literal(node, locals)
            elems = (node.element_nodes || []).map { |e| from_expr(e, locals) }
            "(new Array({#{elems.join(", ")}}))"
          end

          # StringLiteral → (new String("...", N)). Bytes-and-length
          # ctor so embedded null bytes survive (`"a\0b"`). Escape
          # backslash, quote, newline, tab, null, and any non-printable
          # via octal — covers all byte values without depending on the
          # C++ source encoding.
          def from_string_literal(node)
            raw = node.value.raw  # Vm::StringObject -> raw bytes (Ruby String)
            "(new String(#{cpp_string_literal(raw)}, #{raw.bytesize}))"
          end

          def cpp_string_literal(s)
            buf = +'"'
            s.each_byte do |b|
              case b
              when 0x22 then buf << '\\"'
              when 0x5C then buf << '\\\\'
              when 0x0A then buf << '\\n'
              when 0x0D then buf << '\\r'
              when 0x09 then buf << '\\t'
              when 0x00 then buf << '\\0'
              when 0x20..0x7E then buf << b.chr
              else buf << '\\' << format('%03o', b)
              end
            end
            buf << '"'
          end

          # SymbolLiteral → intern("name"). intern() is a forward-declared
          # free function on the runtime that returns the canonical
          # Symbol* for a given name (interning).
          def from_symbol_literal(node)
            # node.value returns the raw Ruby Symbol (.value calls .raw).
            name = node.value.to_s
            escaped = name.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
            %(intern("#{escaped}"))
          end

          # HashLiteral → (new Hash({{k,v}, {k,v}, ...})). **splat
          # entries (k=nil) are skipped — TODO when we hit a real case.
          def from_hash_literal(node, locals)
            pairs = (node.kv_nodes || []).reject { |k, _| k.nil? }
            elems = pairs.map { |k, v| "{#{from_expr(k, locals)}, #{from_expr(v, locals)}}" }
            "(new Hash({#{elems.join(", ")}}))"
          end

          # ConstantRead — resolution priority:
          #   1. Value constant (instance of a user class) → k_NAME()
          #   2. Class constant (any emitted class) → &NAME_CLASS
          #      (a pointer to the eigenclass singleton — Class*-derived)
          #   3. Unknown → raise. Closed-world: we can't statically
          #      resolve this constant, so emitting it is wrong.
          def from_constant_read(node)
            return "k_#{node.name}()" if @user_constants.key?(node.name)
            return "(&#{node.name}_CLASS)" if instantiable_class?(node.name)
            raise EmissionError, "ConstantRead: unresolved constant :#{node.name}"
          end

          # ConstantPath — `Foo::Bar::Baz`. Flatten path components with
          # `_` and look up in the value-constant registry, then class
          # registry. ASCII PascalCase assumption; collisions would
          # need underscore-doubling escape — defer until a real case.
          def from_constant_path(node)
            flat = path_to_cpp_name(node).to_sym
            return "k_#{flat}()" if @user_constants.key?(flat)
            return "(&#{flat}_CLASS)" if instantiable_class?(flat)
            raise EmissionError, "ConstantPath: unresolved path #{path_to_display(node)}"
          end

          # Walk a ConstantRead/ConstantPath/RootNamespaceNode chain and
          # return the flattened C++ identifier ("Foo_Bar_Baz" for
          # Foo::Bar::Baz). RootNamespaceNode (the `::Foo` form) is
          # treated as no-op — we don't have a separate root namespace
          # in box-first; everything's in `namespace Ruby`.
          def path_to_cpp_name(node)
            collect_path(node).join('_')
          end

          def path_to_display(node)
            collect_path(node).join('::')
          end

          def collect_path(node)
            case node
            when Ast::ConstantPath then collect_path(node.parent_node) + [node.name.to_s]
            when Ast::ConstantRead then [node.name.to_s]
            when Ast::RootNamespaceNode then []
            else [node.to_s]  # last-resort fallback
            end
          end

          # A class is instantiable as `new Ruby::X(...)` if it's emitted
          # — either from the user_classes registry or as a Universe-seeded
          # class.
          def instantiable_class?(name)
            @user_classes.key?(name) || Runtime::ALL_CLASSES.any? { |k| k.name == name.to_s }
          end
        end
      end
    end
  end
end
