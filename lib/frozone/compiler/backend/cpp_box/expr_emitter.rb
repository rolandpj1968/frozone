# Box-first C++ backend — expressions: literals, calls, ivar/local r/w,
# control flow.
#
# Every expression evaluates to a `Ruby::BasicObject*`. Method calls go
# through the C++ virtual vtable on the receiver. Literals box on
# construction (`new Ruby::Integer(1)` etc.).
#
# Two entry points:
#   - emit_expr(emit, node, locals) → returns a cpp string (expr position)
#   - emit_stmt(emit, node, locals) → emits via emit.line (stmt position)
# Plus emit_body(emit, body, locals) for a method/top-level body.

module Frozone
  module Compiler
    module Backend
      module CppBox
        class ExprEmitter
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
          def self.method_cpp_name(ruby_name)
            return OP_NAMES[ruby_name] if OP_NAMES.key?(ruby_name)
            s = ruby_name.to_s
            s = s.sub(/\?$/, '_q').sub(/!$/, '_b').sub(/=$/, '_set')
            "m_#{s}"
          end

          # `last_is_return` (true for method bodies) wraps the final
          # statement in `return ...;` if it's an expression — Ruby's
          # implicit return semantics.
          def self.emit_body(emit, body, locals:, last_is_return: false)
            stmts = body.is_a?(Ast::Sequence) ? body.nodes : [body]
            stmts.each_with_index do |n, i|
              last = i == stmts.length - 1
              if last && last_is_return && expression_node?(n)
                emit.line "return #{emit_expr(emit, n, locals)};"
              else
                emit_stmt(emit, n, locals)
              end
            end
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

          def self.emit_stmt(emit, node, locals)
            case node
            when Ast::Return
              emit.line "return #{emit_expr(emit, node.value_node, locals)};"
            when Ast::If
              emit_if_stmt(emit, node, locals)
            when Ast::While
              emit_while_stmt(emit, node, locals)
            when Ast::LocalVariableWrite
              emit_local_write_stmt(emit, node, locals)
            when Ast::MethodCall
              if node.name == :times && node.receiver_node && node.block_node
                emit_times_block(emit, node, locals)
              else
                emit.line "#{emit_expr(emit, node, locals)};"
              end
            when Ast::Sequence
              node.nodes.each { |n| emit_stmt(emit, n, locals) }
            else
              emit.line "#{emit_expr(emit, node, locals)};"
            end
          end

          def self.emit_while_stmt(emit, node, locals)
            emit.line "while (truthy(#{emit_expr(emit, node.condition_node, locals)})) {"
            emit.indented do
              emit_body(emit, node.body_node, locals: locals) if node.body_node
            end
            emit.line "}"
          end

          def self.emit_expr(emit, node, locals)
            case node
            when Ast::IntegerLiteral then "new Integer(#{node.value.raw}LL)"
            when Ast::NilLiteral     then "nil_instance()"
            when Ast::TrueLiteral    then "true_instance()"
            when Ast::FalseLiteral   then "false_instance()"
            when Ast::SelfLiteral    then "this"
            when Ast::ArrayLiteral   then emit_array_literal(emit, node, locals)
            when Ast::LocalVariableRead then node.name.to_s
            when Ast::ConstantRead then emit_constant_read(emit, node)
            when Ast::InstanceVariableRead then "this->iv_#{node.name.to_s.delete_prefix('@')}"
            when Ast::InstanceVariableWrite
              rhs = emit_expr(emit, node.value_node, locals)
              "(this->iv_#{node.name.to_s.delete_prefix('@')} = #{rhs})"
            when Ast::LocalVariableWrite
              rhs = emit_expr(emit, node.value_node, locals)
              if locals.include?(node.name.to_s)
                "(#{node.name} = #{rhs})"
              else
                "/* WARN: lvar decl in expr pos: #{node.name} */ nil_instance()"
              end
            when Ast::MethodCall then emit_method_call(emit, node, locals)
            else
              "/* UNHANDLED: #{node.class.name} */ nil_instance()"
            end
          end

          def self.emit_array_literal(emit, node, locals)
            elems = (node.element_nodes || []).map { |e| emit_expr(emit, e, locals) }
            "new Array({#{elems.join(", ")}})"
          end

          # ConstantRead — for value constants registered with the
          # orchestrator (instances of user classes), emit an accessor
          # call (lazy-initialised function-local static). Class
          # constants used as receiver of `.new` are handled in
          # emit_method_call — they don't reach this path.
          def self.emit_constant_read(emit, node)
            return "k_#{node.name}()" if emit.user_constants.key?(node.name)
            "/* ConstantRead: #{node.name} (no value) */ nil_instance()"
          end

          def self.emit_method_call(emit, node, locals)
            recv = node.receiver_node
            name = node.name
            args = (node.arg_nodes || []).map { |a| emit_expr(emit, a, locals) }

            # ClassName.new(args) → new Ruby::ClassName(args).
            # Bypasses the vtable — direct instantiation.
            if name == :new && recv.is_a?(Ast::ConstantRead) && emit.user_classes.key?(recv.name)
              return "new #{recv.name}(#{args.join(", ")})"
            end

            if recv
              recv_s = emit_expr(emit, recv, locals)
              "#{recv_s}->#{method_cpp_name(name)}(#{args.join(", ")})"
            elsif name == :puts
              "ruby_puts(#{args.join(", ")})"
            else
              "this->#{method_cpp_name(name)}(#{args.join(", ")})"
            end
          end

          def self.emit_local_write_stmt(emit, node, locals)
            rhs = emit_expr(emit, node.value_node, locals)
            if locals.include?(node.name.to_s)
              emit.line "#{node.name} = #{rhs};"
            else
              locals << node.name.to_s
              emit.line "BasicObject* #{node.name} = #{rhs};"
            end
          end

          def self.emit_if_stmt(emit, node, locals)
            cond = emit_expr(emit, node.pred_node, locals)
            emit.line "if (truthy(#{cond})) {"
            emit.indented do
              emit_body(emit, node.then_node, locals: locals) if node.then_node
            end
            if node.else_node
              emit.line "} else {"
              emit.indented { emit_body(emit, node.else_node, locals: locals) }
            end
            emit.line "}"
          end

          # `recv.times { |i| body }` → C++ for-loop. Mirrors mainline's
          # special-case desugaring. recv is a BasicObject*; we extract
          # raw_ via static_cast<Integer*>, except when recv is a literal
          # (then use the int directly).
          def self.emit_times_block(emit, node, locals)
            blk = node.block_node
            var = (blk.required_params || [])[0] || :_i
            locals << var.to_s
            recv_node = node.receiver_node
            count = if recv_node.is_a?(Ast::IntegerLiteral)
                      "#{recv_node.value.raw}LL"
                    else
                      "static_cast<Integer*>(#{emit_expr(emit, recv_node, locals)})->raw_"
                    end
            emit.line "for (int64_t #{var} = 0; #{var} < #{count}; #{var}++) {"
            emit.indented { emit_body(emit, blk.body, locals: locals) }
            emit.line "}"
          end
        end
      end
    end
  end
end
