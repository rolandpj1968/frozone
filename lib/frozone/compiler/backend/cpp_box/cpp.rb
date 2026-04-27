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
require_relative 'method_emitter'

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

          # Above this size (number of elements), an Integer-only Array
          # gets specialised to a raw int64_t[] table + runtime build.
          # Small arrays stay as `(new Array({...}))` brace-init —
          # the per-element overhead doesn't matter at small N.
          INT_ARRAY_THRESHOLD = 8
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
            # Other Kernel-level methods with non-identifier names
            :"`" => "m_backtick",
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
          # Statement-only nodes don't get wrapped in implicit-return;
          # they handle their own control flow or have void value.
          # Ast::If and Ast::Case ARE expression-valid (Ruby's if/case
          # return the taken branch's value) — emitted as ternary or
          # lambda+early-return in expression position, multi-line in
          # statement position.
          def self.expression_node?(node)
            case node
            when Ast::Return, Ast::Sequence, Ast::While, Ast::Until,
                 Ast::Break, Ast::Next then false
            else true
            end
          end

          attr_reader :user_classes, :user_constants
          # Set by Emitter after construction. Needed by from_rescue to
          # render nested-lambda bodies via emit.capture + write_body.
          # Pure-functional otherwise — only the rescue path reaches back.
          attr_accessor :emit
          # Lexical scope chain (outermost-first) of the method currently
          # being emitted. Drives Ruby-style constant lookup: when a
          # method in `Parser::Base` references `Diagnostic::Engine`,
          # we try `Parser::Base::Diagnostic::Engine`, then
          # `Parser::Diagnostic::Engine`, then `Diagnostic::Engine`.
          # Empty list for the top-level body.
          attr_accessor :method_scope
          # Interned integer literals — every unique IntegerLiteral
          # value seen during emission becomes one shared static
          # Integer instance, referenced by address. Without interning,
          # the wq parser stub emits `(new Integer(805LL))` 6K+ times
          # (lexer state machine constants), drowning cc1plus.
          attr_reader :int_literals
          # Monotonic counter for unique helper-variable names —
          # MultipleAssignment uses this to avoid name collisions
          # between multiple MASS statements in the same scope.
          attr_accessor :tmp_counter
          # Big Integer-only Arrays seen during static-state capture
          # (lexer tables in particular — single 700KB+ lines of
          # `(&_f_i_X), ...` brace-init were the C++ compile-time
          # bottleneck). Emitted as raw `int64_t[]` arrays + a runtime
          # build call; cc1plus parses them as cheap static data.
          attr_reader :raw_int_arrays

          def initialize(user_classes:, user_constants:)
            @user_classes = user_classes
            @user_constants = user_constants
            @method_scope = []
            @int_literals = {}
            @raw_int_arrays = []
            @tmp_counter = 0
          end

          def next_tmp_id = (@tmp_counter += 1)

          # Return a reference to the interned Integer for `value`.
          # Each unique value becomes one named static `_f_i_<N>` (with
          # negatives prefixed `_f_i_n<abs>`). The decls are emitted by
          # write_int_literals after class defs are complete.
          def intern_int(value)
            @int_literals[value] = true unless @int_literals.key?(value)
            "(&#{int_literal_name(value)})"
          end

          def int_literal_name(value) = value >= 0 ? "_f_i_#{value}" : "_f_i_n#{-value}"

          # Emit the raw int64_t[] tables collected during static-state
          # capture. Each goes after Integer is complete (so the runtime
          # `build_int_array` helper can construct Integer instances).
          def write_raw_int_arrays(emit)
            return if @raw_int_arrays.empty?
            emit.line "// Raw int64_t tables for large Integer-only Arrays —"
            emit.line "// build_int_array() boxes them into Array+Integer at static-init"
            emit.line "// time. Cuts source size and cc1plus parse time vs emitting"
            emit.line "// each element as `(&_f_i_X), `."
            @raw_int_arrays.each_with_index do |values, idx|
              emit.line "static const int64_t __TBL_INT_#{idx}__[#{values.size}] = {#{values.join(",")}};"
            end
            emit.blank
          end

          # Emit the named static decls. Positioned after all class
          # definitions (Integer must be complete to call its ctor).
          # Each is its own variable — cc1plus parses each
          # independently, much cheaper than one big array initializer
          # for the wq parser scale (~thousands of unique literals).
          def write_int_literals(emit)
            return if @int_literals.empty?
            emit.line "// Interned Integer literals — every unique IntegerLiteral and"
            emit.line "// IntegerObject in the program graph maps to one shared static"
            emit.line "// instance. Direct named statics (rather than an array) so"
            emit.line "// cc1plus parses each as an independent declaration."
            @int_literals.each_key do |value|
              emit.line "Integer #{int_literal_name(value)}(#{value}LL);"
            end
            emit.blank
          end

          # Top-level dispatch — turns an AST node into a cpp expression
          # string. Pure: no side effects. Recursive into sub-expressions.
          def from_expr(node, locals)
            raise EmissionError, "from_expr: nil node — caller passed missing AST" if node.nil?
            case node
            when Ast::IntegerLiteral then intern_int(node.value.raw)
            when Ast::FloatLiteral   then "(new Float(#{node.value}))"
            when Ast::NilLiteral     then "nil_instance()"
            when Ast::TrueLiteral    then "true_instance()"
            when Ast::FalseLiteral   then "false_instance()"
            when Ast::SelfLiteral    then "this"
            when Ast::SymbolLiteral  then from_symbol_literal(node)
            when Ast::StringLiteral  then from_string_literal(node)
            when Ast::InterpolatedString then from_interpolated_string(node, locals)
            when Ast::ArrayLiteral   then from_array_literal(node, locals)
            when Ast::HashLiteral    then from_hash_literal(node, locals)
            when Ast::RangeLiteral   then from_range_literal(node, locals)
            when Ast::LocalVariableRead then MethodEmitter.local_cpp_name(node.name)
            when Ast::ConstantRead then from_constant_read(node)
            when Ast::ConstantPath then from_constant_path(node)
            when Ast::InstanceVariableRead then "this->iv_#{node.name.to_s.delete_prefix('@')}"
            when Ast::InstanceVariableWrite
              rhs = from_expr(node.value_node, locals)
              "(this->iv_#{node.name.to_s.delete_prefix('@')} = #{rhs})"
            when Ast::LocalVariableWrite
              rhs = from_expr(node.value_node, locals)
              if locals.include?(node.name.to_s)
                "(#{MethodEmitter.local_cpp_name(node.name)} = #{rhs})"
              else
                # Local-decl in expr position needs scope hoisting
                # (declare in outer scope, assign here). Not implemented.
                raise EmissionError,
                  "LocalVariableWrite in expression position requires scope-hoisting (var: #{node.name}) — not implemented"
              end
            when Ast::MethodCall then from_method_call(node, locals)
            when Ast::AttributeWrite then from_attribute_write(node, locals)
            when Ast::IndexOperatorWrite then from_index_op_write(node, locals)
            when Ast::And then from_and(node, locals)
            when Ast::Or then from_or(node, locals)
            when Ast::If then from_if(node, locals)
            when Ast::Case then from_case(node, locals)
            when Ast::Yield then from_yield(node, locals)
            when Ast::IntrinsicCall then from_intrinsic_call(node, locals)
            when Ast::Rescue then from_rescue(node, locals)
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

            # `raise` is a statement-like keyword in Ruby that we lower
            # to a C++ `throw` wrapped in a lambda (so it composes in
            # expression position too).
            return from_raise(arg_nodes, locals) if !recv && name == :raise

            # `block_given?` checks the ENCLOSING method's block — the
            # `_block` local that unpack_params binds. Going through the
            # universal vtable would receive the block passed to the
            # block_given? call itself, not the enclosing method's,
            # which is wrong. Special-case to a direct check.
            return "boxed_bool(_block != nullptr)" if !recv && name == :block_given?

            # `.new` has no special case: `Foo.new(args)` dispatches via
            # the universal protocol on the eigenclass singleton — i.e.
            # `(&Foo_CLASS)->m_new(args, kwargs, block)`. The eigenclass
            # auto-emits an m_new override that does
            # `Foo* obj = new Foo(); obj->m_initialize(args, ...); return obj;`.

            # Block-bearing call site (other than the .times for-loop
            # special-case which write_stmt handles): wrap the block as
            # a Proc and pass as the third call-protocol arg.
            block_arg = if node.block_node && !(name == :times && recv)
                          from_block_as_proc(node.block_node, locals)
                        else
                          "nullptr"
                        end
            args_array = build_args_array(arg_nodes, locals)
            kwargs_arg = build_kwargs_hash(node.kw_arg_nodes || [], locals)

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

          # Build the kwargs Hash for a call. Empty kw list → nullptr
          # (no allocation cost when there are no kw args). Each entry
          # is `{intern("key"), <value_expr>}` — Symbol keys.
          # **splat handling deferred — kw_splat_nodes raise EmissionError.
          def build_kwargs_hash(kw_arg_nodes, locals)
            return "nullptr" if kw_arg_nodes.empty?
            entries = kw_arg_nodes.map do |key_node, value_node|
              key_name = key_node.is_a?(Ast::SymbolLiteral) ? key_node.value.to_s : nil
              raise EmissionError, "non-symbol kw key not supported" unless key_name
              "{intern(#{cpp_string_literal(key_name)}), static_cast<BasicObject*>(#{from_expr(value_node, locals)})}"
            end
            "(new Hash({#{entries.join(", ")}}))"
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

          # `raise` lowering. Forms supported:
          #   raise                — re-raise current exception (`throw;`)
          #   raise X              — sugar for `X.new` (universal m_new)
          #   raise X, "msg"       — sugar for `X.new("msg")`
          #   raise X.new("msg")   — already a Foo.new dispatch; just throw
          #   raise "msg"          — sugar for `RuntimeError.new("msg")`
          #   raise <expr>         — throw <expr> (assumed Exception-typed)
          # All forms wrap in a lambda returning BasicObject* so they
          # compose in expression position. C++ `throw` is void-typed,
          # so it can't appear directly in `return throw ...;`.
          # Construction routes through the universal m_new protocol so
          # exception subclasses without their own initialize still get
          # the parent's m_initialize via the eigenclass auto-dispatch.
          def from_raise(arg_nodes, locals)
            return "([&]() -> BasicObject* { throw; }())" if arg_nodes.empty?

            first = arg_nodes[0]
            if first.is_a?(Ast::ConstantRead) || first.is_a?(Ast::ConstantPath)
              parts = first.is_a?(Ast::ConstantRead) ? [first.name.to_s] : collect_path(first)
              flat = resolve_constant(parts)
              raise EmissionError, "raise: unknown exception class #{parts.join('::')}" unless flat && instantiable_class?(flat)
              ctor_args = arg_nodes.drop(1).map { |a| "static_cast<BasicObject*>(#{from_arg(a, locals)})" }
              args_array = "(new Array({#{ctor_args.join(", ")}}))"
              return "([&]() -> BasicObject* { throw static_cast<Exception*>((&#{flat}_CLASS)->m_new(#{args_array}, nullptr, nullptr)); }())"
            end

            if arg_nodes.length == 1
              # `raise "msg"` is sugar for `raise RuntimeError.new("msg")`.
              if first.is_a?(Ast::StringLiteral) || first.is_a?(Ast::InterpolatedString)
                msg_str = from_expr(first, locals)
                return %(([&]() -> BasicObject* { throw static_cast<Exception*>((&RuntimeError_CLASS)->m_new((new Array({static_cast<BasicObject*>(#{msg_str})})), nullptr, nullptr)); }()))
              end
              expr_str = from_expr(first, locals)
              return "([&]() -> BasicObject* { throw static_cast<Exception*>(#{expr_str}); }())"
            end
            raise EmissionError, "raise: unsupported arg shape (#{arg_nodes.length} args)"
          end

          # begin/rescue/else/ensure → self-invoking lambda. Body, each
          # rescue arm, and else_node each render as a NESTED lambda
          # using emit.capture + write_body(last_is_return: true), so
          # multi-statement non-expression blocks are supported. The
          # ensure_node becomes an EnsureGuard (RAII) at the top of the
          # outer lambda — runs on any exit (return, exception, rethrow).
          # No clause matched → re-throw, which propagates through the
          # ensure guard.
          def from_rescue(node, locals)
            check_no_break_next!(node, "rescue")
            buf = +"([&]() -> BasicObject* { "
            if node.ensure_node
              buf << "EnsureGuard _eg([&]() #{body_as_block(node.ensure_node, locals, last_is_return: false)}); "
            end
            buf << "try { "
            if node.else_node
              # Body's value discarded; else_node provides the value.
              buf << "#{body_as_lambda_call(node.body, locals)}; "
              buf << "return #{body_as_lambda_call(node.else_node, locals)}; "
            else
              buf << "return #{body_as_lambda_call(node.body, locals)}; "
            end
            buf << "} catch (Exception* e_) { "
            (node.rescue_clauses || []).each do |clause|
              cond = rescue_clause_condition(clause)
              bind_locals = locals.dup
              bind_str = ""
              if clause.var_name
                bind_locals << clause.var_name.to_s
                bind_str = "BasicObject* #{clause.var_name} = e_; "
              end
              arm_call = body_as_lambda_call(clause.body, bind_locals)
              buf << "if (#{cond}) { #{bind_str}return #{arm_call}; } "
            end
            buf << "throw; } }())"
            buf
          end

          # Build the dynamic_cast-based condition for one rescue clause.
          # Bare rescue (no exception_nodes) catches StandardError per
          # Ruby semantics. Exception class names come from ConstantRead
          # / ConstantPath; non-constant exception lists raise EmissionError.
          def rescue_clause_condition(clause)
            return "dynamic_cast<StandardError*>(e_) != nullptr" if clause.exception_nodes.empty?
            clause.exception_nodes.map { |n|
              cls = exception_class_name(n)
              "dynamic_cast<#{cls}*>(e_) != nullptr"
            }.join(" || ")
          end

          def exception_class_name(node)
            name = case node
                   when Ast::ConstantRead then node.name.to_s
                   when Ast::ConstantPath then path_to_cpp_name(node)
                   else
                     raise EmissionError, "rescue: non-constant exception spec (#{node.class.name})"
                   end
            unless instantiable_class?(name.to_sym)
              raise EmissionError, "rescue: unknown exception class :#{name}"
            end
            name
          end

          # Render a body as `[&]() -> BasicObject* { ... return last; }()`
          # — the nested lambda captures all enclosing locals by reference
          # and returns the value of the last expression. Used by
          # from_rescue for body / else / arm bodies.
          def body_as_lambda_call(body, locals)
            "#{body_as_lambda(body, locals, last_is_return: true)}()"
          end

          def body_as_lambda(body, locals, last_is_return:)
            "[&]() -> BasicObject* #{body_as_block(body, locals, last_is_return: last_is_return)}"
          end

          # Render `{ ... }` for a body — used both as the lambda body
          # and as the EnsureGuard lambda body. captured via emit so any
          # statement type (if/while/case) is supported. Trailing
          # `return nil_instance();` is a safety net for empty bodies
          # and last_is_return=false paths.
          def body_as_block(body, locals, last_is_return:)
            return "{ return nil_instance(); }" unless body
            inner = @emit.capture do
              ExprEmitter.write_body(@emit, body, locals: locals, last_is_return: last_is_return)
            end
            "{ #{inner.gsub("\n", " ")} return nil_instance(); }"
          end

          # IntrinsicCall lowering. `Intrinsics.foo(self, args...)`
          # bypasses the universal protocol and emits direct C++
          # specialised to the receiver type encoded in the intrinsic
          # name (`array_*` → cast to Array*, `integer__plus_` → cast to
          # Integer*, etc.). For closed-world AOT this is exactly the
          # specialisation we want — no vtable, no Array allocation
          # for args, no static_cast at runtime, just the underlying op.
          # Templates are explicit per-intrinsic (no name-based
          # heuristic — too many edge cases). Unknown intrinsic →
          # EmissionError → method skipped (graceful degradation).
          def from_intrinsic_call(node, locals)
            name = node.method.name
            template = INTRINSIC_TEMPLATES[name]
            raise EmissionError, "intrinsic :#{name} not yet supported" unless template
            args = node.param_nodes.map { |p| from_expr(p, locals) }
            template.call(*args)
          rescue ArgumentError => e
            raise EmissionError, "intrinsic :#{name}: #{e.message}"
          end

          # Minimal starter set — covers Array+Integer ops needed for
          # selfcompile_wq2 to get past Array#clear. Each lambda takes
          # the cpp expression strings for the receiver and any extra
          # args and returns the C++ expression. Add more as the
          # compile/run cycle reveals them.
          INTRINSIC_TEMPLATES = {
            # Array
            array_length: ->(self_) { "(new Integer(static_cast<int64_t>(static_cast<Array*>(#{self_})->data.size())))" },
            array_at: ->(self_, i) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{self_}); int64_t _i = static_cast<Integer*>(#{i})->raw_; return (_i < 0 || _i >= (int64_t)_a->data.size()) ? nil_instance() : _a->data[_i]; }())"
            },
            array_push: ->(self_, v) { "(static_cast<Array*>(#{self_})->data.push_back(#{v}), #{self_})" },
            array_replace: ->(self_, other) {
              "(static_cast<Array*>(#{self_})->data = static_cast<Array*>(#{other})->data, #{self_})"
            },
            array_dup: ->(self_) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{self_}); Array* _r = new Array(); _r->data = _a->data; return _r; }())"
            },
            array_concat: ->(self_, other) {
              "([&]() -> BasicObject* { auto* _a = static_cast<Array*>(#{self_}); auto* _b = static_cast<Array*>(#{other}); _a->data.insert(_a->data.end(), _b->data.begin(), _b->data.end()); return _a; }())"
            },

            # Integer arithmetic — direct unboxed ops on raw_ + box.
            integer__plus_:  ->(s, o) { "(new Integer(static_cast<Integer*>(#{s})->raw_ + static_cast<Integer*>(#{o})->raw_))" },
            integer__minus_: ->(s, o) { "(new Integer(static_cast<Integer*>(#{s})->raw_ - static_cast<Integer*>(#{o})->raw_))" },
            integer__star_:  ->(s, o) { "(new Integer(static_cast<Integer*>(#{s})->raw_ * static_cast<Integer*>(#{o})->raw_))" },
            integer_spaceship: ->(s, o) {
              "(new Integer(static_cast<int64_t>((static_cast<Integer*>(#{s})->raw_ > static_cast<Integer*>(#{o})->raw_) - (static_cast<Integer*>(#{s})->raw_ < static_cast<Integer*>(#{o})->raw_))))"
            },
            float_spaceship: ->(s, o) {
              "(new Integer(static_cast<int64_t>((static_cast<Float*>(#{s})->raw_ > static_cast<Float*>(#{o})->raw_) - (static_cast<Float*>(#{s})->raw_ < static_cast<Float*>(#{o})->raw_))))"
            },

            integer__lt_:    ->(s, o) { "boxed_bool(static_cast<Integer*>(#{s})->raw_ <  static_cast<Integer*>(#{o})->raw_)" },
            integer__gt_:    ->(s, o) { "boxed_bool(static_cast<Integer*>(#{s})->raw_ >  static_cast<Integer*>(#{o})->raw_)" },
            integer__le_:    ->(s, o) { "boxed_bool(static_cast<Integer*>(#{s})->raw_ <= static_cast<Integer*>(#{o})->raw_)" },
            integer__ge_:    ->(s, o) { "boxed_bool(static_cast<Integer*>(#{s})->raw_ >= static_cast<Integer*>(#{o})->raw_)" },

            # Range — direct field access on the C++ struct (begin_,
            # end_, exclude_end_, initialized_).
            range_set: ->(self_, b, e, excl) {
              "([&]() -> BasicObject* { auto* _r = static_cast<Range*>(#{self_}); _r->begin_ = #{b}; _r->end_ = #{e}; _r->exclude_end_ = (#{excl} == true_instance()); _r->initialized_ = true; return nil_instance(); }())"
            },
            range_begin:        ->(self_) { "(static_cast<Range*>(#{self_})->begin_)" },
            range_end:          ->(self_) { "(static_cast<Range*>(#{self_})->end_)" },
            range_exclude_end:  ->(self_) { "boxed_bool(static_cast<Range*>(#{self_})->exclude_end_)" },
            range_initialized_q:->(self_) { "boxed_bool(static_cast<Range*>(#{self_})->initialized_)" },

            # String — direct byte-vector access. encoding/force_encoding
            # are stubs: we return a literal string for `encoding` so
            # core/4.0/ code that passes it through (e.g. reverse +
            # force_encoding(encoding)) doesn't blow up. Real encoding
            # tracking can come back when something needs it.
            string_encoding: ->(_self_) { %((new String("UTF-8", 5))) },
            string_force_encoding: ->(self_, _enc) { "(#{self_})" },

            string_get_byte: ->(self_, i) {
              "(new Integer(static_cast<int64_t>(static_cast<String*>(#{self_})->bytes[static_cast<Integer*>(#{i})->raw_])))"
            },
            string_setbyte: ->(self_, i, b) {
              "(static_cast<String*>(#{self_})->bytes[static_cast<Integer*>(#{i})->raw_] = static_cast<std::uint8_t>(static_cast<Integer*>(#{b})->raw_), #{b})"
            },
            string_bytesize: ->(self_) {
              "(new Integer(static_cast<int64_t>(static_cast<String*>(#{self_})->bytes.size())))"
            },

            # Object identity / class — needed by core/4.0 dispatch helpers.
            object_is_a: ->(self_, klass) { "boxed_bool(dynamic_cast<Class*>(#{klass}) != nullptr && #{self_}->m_is_a_q((new Array({#{klass}})), nullptr, nullptr) == true_instance())" },
            object_class: ->(self_) { "#{self_}->m_class((new Array({})), nullptr, nullptr)" },
            basic_object__equal_equal_: ->(s, o) { "boxed_bool(#{s} == #{o})" },
            basic_object___id__: ->(s) { "(new Integer(reinterpret_cast<int64_t>(#{s})))" },
          }.freeze

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
          # `&expr` (Ast::BlockArg) is forwarded as a Proc* — the value
          # must already be a Proc-typed local; SymbolProc / to_proc
          # coercions are deferred (raise EmissionError).
          def from_block_as_proc(block_node, locals)
            if block_node.is_a?(Ast::BlockArg)
              # &:sym would need SymbolProc-style coercion (synthesise a
              # block that calls the named method on the arg). Defer.
              if block_node.value_node.is_a?(Ast::SymbolLiteral)
                raise EmissionError, "&:sym block-arg coercion not yet supported"
              end
              return "static_cast<Proc*>(#{from_expr(block_node.value_node, locals)})"
            end
            params = block_node.required_params || []
            if (block_node.respond_to?(:optional_params) && (block_node.optional_params || []).any?) ||
               (block_node.respond_to?(:rest_param) && block_node.rest_param) ||
               (block_node.respond_to?(:post_params) && (block_node.post_params || []).any?)
              raise EmissionError, "block with optional/rest/post params not yet supported"
            end
            params.each do |p|
              unless p.is_a?(Symbol) || p.is_a?(String)
                raise EmissionError, "block param destructuring (#{p.class.name}) not yet supported"
              end
            end
            check_no_break_next!(block_node.body, "block")
            block_locals = locals.dup
            params.each { |p| block_locals << p.to_s }

            body = block_node.body
            stmts = body.is_a?(Ast::Sequence) ? body.nodes : (body ? [body] : [])

            parts = []
            # Bind each block param to args->data[i]. The Proc lambda
            # always takes the full args array — supports blocks with
            # 0, 1, or many params. Out-of-range reads return nil.
            params.each_with_index do |p, i|
              parts << "BasicObject* #{MethodEmitter.local_cpp_name(p)} = (#{i} < (int)__blkargs__->data.size()) ? __blkargs__->data[#{i}] : nil_instance();"
            end
            stmts.each_with_index do |n, i|
              s = from_expr(n, block_locals)
              if i == stmts.length - 1
                parts << "return #{s};"
              else
                parts << "#{s};"
              end
            end
            parts << "return nil_instance();" if stmts.empty?

            "(new Proc([&](Array* __blkargs__) -> BasicObject* { #{parts.join(' ')} }))"
          end

          # `arr[k] = v` parses as AttributeWrite(name=:[]=, receiver,
          # arg_nodes=[k, v]). Emit as a vtable call to m_aset via
          # the universal protocol.
          def from_attribute_write(node, locals)
            # Implicit-receiver AttributeWrite (`self.foo = x` lowered
            # without an explicit self_node, or just `foo = x` when foo
            # is detected as a writer call) → dispatch on `this`.
            recv_s = node.receiver_node ? from_expr(node.receiver_node, locals) : "this"
            args = (node.arg_nodes || []).map { |a| from_expr(a, locals) }
            args_array = "(new Array({#{args.join(", ")}}))"
            "#{recv_s}->#{Cpp.method_name(node.name)}(#{args_array}, nullptr, nullptr)"
          end

          # `arr[i] op= val` → `arr[i] = arr[i] op val`. Receiver and
          # indices evaluated once each; for `+=`, `-=`, etc.
          # `||=` / `&&=` not yet supported (need short-circuit).
          # Multi-index (`arr[i,j] += val`) emits as expected — m_aref/
          # m_aset with the full index list.
          def from_index_op_write(node, locals)
            op = node.operator
            raise EmissionError, "IndexOperatorWrite op :#{op} not yet supported" if %i[|| &&].include?(op)
            recv_str = node.receiver_node ? from_expr(node.receiver_node, locals) : "this"
            idx_strs = (node.index_arg_nodes || []).map { |a| from_arg(a, locals) }
            val_str = from_expr(node.value_node, locals)
            tag = next_tmp_id
            recv_t = "__iow_recv_#{tag}__"
            idx_array = "(new Array({#{idx_strs.join(", ")}}))"
            cpp_op = Cpp.method_name(op)
            # `recv->aref(idx) op val` → `recv->aset(idx, that)`. Using a
            # comma operator to bind recv once, then form the aset call.
            "([&]() -> BasicObject* { auto* #{recv_t} = #{recv_str}; auto* _idx = #{idx_array}; return #{recv_t}->m_aset((new Array({#{idx_strs.join(", ")}, #{recv_t}->m_aref(_idx, nullptr, nullptr)->#{cpp_op}((new Array({#{val_str}})), nullptr, nullptr)})), nullptr, nullptr); }())"
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
          # break/next inside the case-arms would emit C++ break/continue
          # inside a lambda, which is invalid (lambda blocks loop scope).
          def from_case(node, locals)
            check_no_break_next!(node, "case-as-expression")
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

          # Raise EmissionError if any break/next is reachable from this
          # node without an intervening nested-loop boundary. Used by
          # lambda-wrapped emission (rescue, case-as-expr, blocks) where
          # C++ break/continue would land in the lambda scope, not the
          # enclosing loop.
          def check_no_break_next!(node, ctx)
            if contains_loop_escape?(node)
              raise EmissionError, "break/next inside #{ctx} — lambda boundary blocks loop scope, not yet supported"
            end
          end

          def contains_loop_escape?(node)
            return false unless node.is_a?(Ast::Node)
            return true if node.is_a?(Ast::Break) || node.is_a?(Ast::Next)
            # Stop at things that introduce their own loop scope (their
            # break/next bind there, not to our enclosing).
            return false if node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda) ||
                            node.is_a?(Ast::While) || node.is_a?(Ast::Until)
            (node.respond_to?(:children) ? node.children : []).any? { |c| contains_loop_escape?(c) }
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
          # `"foo #{x} bar"` → chain of String#+ calls. StringLiteral
          # parts emit directly; other parts coerce via m_to_s. The
          # whole chain starts from an empty String so an interpolated
          # string with no leading literal still yields a String*.
          def from_interpolated_string(node, locals)
            parts = node.parts || []
            return %((new String("", 0))) if parts.empty?
            chain = +%((new String("", 0)))
            parts.each do |part|
              part_str = if part.is_a?(Ast::StringLiteral)
                           from_string_literal(part)
                         else
                           "#{from_expr(part, locals)}->m_to_s((new Array({})), nullptr, nullptr)"
                         end
              chain << "->m_plus((new Array({#{part_str}})), nullptr, nullptr)"
            end
            "(#{chain})"
          end

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

          # `(a..b)` / `(a...b)` literals — direct construction of a
          # Range with begin_/end_/exclude_end_ set. No m_new dispatch
          # since the literal already knows the values; matches how
          # ArrayLiteral and HashLiteral lower.
          def from_range_literal(node, locals)
            b = node.begin_node ? from_expr(node.begin_node, locals) : "nil_instance()"
            e = node.end_node   ? from_expr(node.end_node,   locals) : "nil_instance()"
            excl = node.exclusive ? "true" : "false"
            "([&]() -> BasicObject* { Range* _r = new Range(); _r->begin_ = #{b}; _r->end_ = #{e}; _r->exclude_end_ = #{excl}; _r->initialized_ = true; return _r; }())"
          end

          # ConstantRead / ConstantPath — Ruby-style lookup walks the
          # lexical scope chain. For `Diagnostic::Engine` written inside
          # `Parser::Base`, try `Parser::Base::...`, then `Parser::...`,
          # then top-level `...`. First match in user_classes /
          # user_constants wins. Callers format the result.
          def from_constant_read(node) = format_constant(resolve_constant([node.name.to_s]) ||
            (raise EmissionError, "ConstantRead: unresolved constant :#{node.name}"))

          def from_constant_path(node)
            parts = collect_path(node)
            absolute = parts.first == "" ||
                       (node.respond_to?(:parent_node) && node.parent_node.is_a?(Ast::RootNamespaceNode))
            resolved = absolute ? resolve_top_level(parts.reject(&:empty?)) : resolve_constant(parts)
            return format_constant(resolved) if resolved
            raise EmissionError, "ConstantPath: unresolved path #{parts.join('::')}"
          end

          # Walk the method's lexical scope chain (innermost-first),
          # trying each prefix joined with `parts`. Falls back to the
          # top-level (bare path) lookup last. Returns the resolved
          # flat name as a Symbol (e.g. `:Parser_Diagnostic_Engine`),
          # or nil if no scope yields a match.
          def resolve_constant(parts)
            (scope_prefixes + [[]]).each do |prefix|
              flat = (prefix + parts).join("_").to_sym
              return flat if @user_constants.key?(flat) || instantiable_class?(flat)
            end
            nil
          end

          def resolve_top_level(parts)
            flat = parts.join("_").to_sym
            (@user_constants.key?(flat) || instantiable_class?(flat)) ? flat : nil
          end

          # Format a resolved Symbol as the right C++ expression:
          # accessor call for value constants, address-of-singleton for
          # classes.
          def format_constant(name)
            return "k_#{name}()" if @user_constants.key?(name)
            "(&#{name}_CLASS)"
          end

          # The lexical scope chain rendered as part-arrays, innermost
          # first. `Parser::Base` (innermost) → `["Parser", "Base"]`.
          # Skips Object (the top-level scope).
          def scope_prefixes
            (@method_scope || []).reverse.filter_map { |s|
              next nil unless s.respond_to?(:full_name) && s.full_name
              fname = s.full_name.to_s
              next nil if fname == "Object"
              fname.split("::")
            }
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

          # Resolve a Vm::ClassObject to its emitted flat name (the
          # eigenclass singleton's basename). Walks `full_name` and
          # tries each successive prefix against user_classes /
          # Universe. Returns nil if not found (caller raises).
          def class_object_to_flat(cls)
            fname = cls.full_name.to_s
            flat = fname.gsub("::", "_").to_sym
            return flat if instantiable_class?(flat)
            nil
          end

          # Float literal — Ruby's Float::INFINITY / Float::NAN
          # interpolate to "Infinity" / "NaN" which aren't C++ literals.
          # Use the standard C++ macros for those, plain digits for finite.
          def float_literal(v)
            return "(new Float(std::numeric_limits<double>::infinity()))" if v == Float::INFINITY
            return "(new Float(-std::numeric_limits<double>::infinity()))" if v == -Float::INFINITY
            return "(new Float(std::numeric_limits<double>::quiet_NaN()))" if v.is_a?(Float) && v.nan?
            "(new Float(#{v}))"
          end

          # Render a Vm value as a C++ expression that produces the
          # equivalent box at runtime. Used by static-state capture
          # (ClassObject ivar materialization). Recursive across
          # arrays / hashes; returns plain literals for scalars.
          # Unsupported types raise EmissionError so the caller can
          # skip the offending init.
          def emit_vm_value(val)
            case val
            when Vm::IntegerObject then intern_int(val.raw)
            when Vm::FloatObject   then float_literal(val.raw)
            when Vm::SymbolObject  then "intern(#{cpp_string_literal(val.raw.to_s)})"
            when Vm::StringObject  then "(new String(#{cpp_string_literal(val.raw)}, #{val.raw.bytesize}))"
            when Vm::NilObject     then "nil_instance()"
            when Vm::TrueObject    then "true_instance()"
            when Vm::FalseObject   then "false_instance()"
            when Vm::ArrayObject
              # Specialise large Integer-only arrays: emit the values
              # as a static `int64_t[]` and build the Array at runtime.
              # Saves ~3x source size vs `(&_f_i_X), ...` per element
              # and lets cc1plus parse the table as cheap static data.
              if val.raw.size > INT_ARRAY_THRESHOLD && val.raw.all? { |e| e.is_a?(Vm::IntegerObject) }
                idx = @raw_int_arrays.size
                @raw_int_arrays << val.raw.map(&:raw)
                "build_int_array(__TBL_INT_#{idx}__, #{val.raw.size})"
              else
                elems = val.raw.map { |e| emit_vm_value(e) }
                "(new Array({#{elems.join(", ")}}))"
              end
            when Vm::HashObject
              pairs = val.raw.map { |k, v| "{#{emit_vm_value(k)}, #{emit_vm_value(v)}}" }
              "(new Hash({#{pairs.join(", ")}}))"
            when Vm::ClassObject
              flat = class_object_to_flat(val)
              raise EmissionError, "emit_vm_value: ClassObject #{val.full_name} not in emitted set" unless flat
              "(&#{flat}_CLASS)"
            when Vm::ObjectObject
              # If this object is itself one of our registered user
              # constants, emit a reference to its accessor (its ivars
              # are populated by static_state_init).
              flat = @user_constants.find { |_, v| v.equal?(val) }&.first
              raise EmissionError, "emit_vm_value: ObjectObject (#{val.class_object&.full_name}) not in user_constants" unless flat
              "k_#{flat}()"
            else
              raise EmissionError, "emit_vm_value: unsupported VM value class #{val.class.name}"
            end
          end

        end
      end
    end
  end
end
