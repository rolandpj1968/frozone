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
          # Statement-only nodes (If, Return, etc.) don't get wrapped
          # in implicit-return; they handle their own control flow.
          def self.expression_node?(node)
            case node
            when Ast::Return, Ast::If, Ast::Sequence then false
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
            when Ast::NilLiteral     then "nil_instance()"
            when Ast::TrueLiteral    then "true_instance()"
            when Ast::FalseLiteral   then "false_instance()"
            when Ast::SelfLiteral    then "this"
            when Ast::ArrayLiteral   then from_array_literal(node, locals)
            when Ast::LocalVariableRead then node.name.to_s
            when Ast::ConstantRead then from_constant_read(node)
            when Ast::InstanceVariableRead then "this->iv_#{node.name.to_s.delete_prefix('@')}"
            when Ast::InstanceVariableWrite
              rhs = from_expr(node.value_node, locals)
              "(this->iv_#{node.name.to_s.delete_prefix('@')} = #{rhs})"
            when Ast::LocalVariableWrite
              rhs = from_expr(node.value_node, locals)
              if locals.include?(node.name.to_s)
                "(#{node.name} = #{rhs})"
              else
                "/* WARN: lvar decl in expr pos: #{node.name} */ nil_instance()"
              end
            when Ast::MethodCall then from_method_call(node, locals)
            when Ast::AttributeWrite then from_attribute_write(node, locals)
            when Ast::And then from_and(node, locals)
            when Ast::Or then from_or(node, locals)
            when Ast::Sequence
              # `(a)` and `(a, b, c)` both work as comma-operator —
              # value is the last subexpression.
              "(#{node.nodes.map { |n| from_expr(n, locals) }.join(", ")})"
            else
              "/* UNHANDLED: #{node.class.name} */ nil_instance()"
            end
          end

          def from_method_call(node, locals)
            recv = node.receiver_node
            name = node.name
            args = (node.arg_nodes || []).map { |a| from_expr(a, locals) }

            # ClassName.new(args) → (new Ruby::ClassName(args)).
            # Bypasses the vtable — direct instantiation. Wrap in parens
            # so trailing -> on the result binds tighter than `new`.
            if name == :new && recv.is_a?(Ast::ConstantRead) && instantiable_class?(recv.name)
              return "(new #{recv.name}(#{args.join(", ")}))"
            end

            if recv
              "#{from_expr(recv, locals)}->#{Cpp.method_name(name)}(#{args.join(", ")})"
            elsif name == :puts
              "ruby_puts(#{args.join(", ")})"
            else
              "this->#{Cpp.method_name(name)}(#{args.join(", ")})"
            end
          end

          # `arr[k] = v` parses as AttributeWrite(name=:[]=, receiver,
          # arg_nodes=[k, v]). Emit as a vtable call to m_aset.
          # Returns the assigned value (Ruby semantics).
          def from_attribute_write(node, locals)
            recv_s = from_expr(node.receiver_node, locals)
            args = (node.arg_nodes || []).map { |a| from_expr(a, locals) }
            "#{recv_s}->#{Cpp.method_name(node.name)}(#{args.join(", ")})"
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

          def from_array_literal(node, locals)
            elems = (node.element_nodes || []).map { |e| from_expr(e, locals) }
            "(new Array({#{elems.join(", ")}}))"
          end

          # ConstantRead — for value constants registered with the
          # orchestrator (instances of user classes), emit an accessor
          # call (lazy-initialised function-local static). Class
          # constants used as receiver of `.new` are handled in
          # from_method_call — they don't reach this path.
          def from_constant_read(node)
            return "k_#{node.name}()" if @user_constants.key?(node.name)
            "/* ConstantRead: #{node.name} (no value) */ nil_instance()"
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
