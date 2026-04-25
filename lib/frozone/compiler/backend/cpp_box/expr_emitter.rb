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
            :+   => "m_plus",
            :-   => "m_minus",
            :*   => "m_mul",
            :/   => "m_div",
            :%   => "m_mod",
            :<   => "m_lt",
            :>   => "m_gt",
            :<=  => "m_le",
            :>=  => "m_ge",
            :==  => "m_eq_q",
            :!=  => "m_ne_q",
            :<<  => "m_lshift",
            :>>  => "m_rshift",
          }.freeze

          def self.emit_body(emit, body, locals:)
            stmts = body.is_a?(Ast::Sequence) ? body.nodes : [body]
            stmts.each { |n| emit_stmt(emit, n, locals) }
          end

          def self.emit_stmt(emit, node, locals)
            case node
            when Ast::Return
              emit.line "return #{emit_expr(emit, node.value_node, locals)};"
            when Ast::If
              emit_if_stmt(emit, node, locals)
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

          def self.emit_expr(emit, node, locals)
            case node
            when Ast::IntegerLiteral then "new Integer(#{node.value.raw}LL)"
            when Ast::NilLiteral     then "static_cast<BasicObject*>(&NIL_INSTANCE)"
            when Ast::TrueLiteral    then "static_cast<BasicObject*>(&TRUE_INSTANCE)"
            when Ast::FalseLiteral   then "static_cast<BasicObject*>(&FALSE_INSTANCE)"
            when Ast::LocalVariableRead then node.name.to_s
            when Ast::LocalVariableWrite
              rhs = emit_expr(emit, node.value_node, locals)
              if locals.include?(node.name.to_s)
                "(#{node.name} = #{rhs})"
              else
                # Inline local decl in expression position is awkward in C++.
                # Defer: treat as comment + nil, fix when we see a real case.
                "/* WARN: lvar decl in expr pos: #{node.name} */ static_cast<BasicObject*>(&NIL_INSTANCE)"
              end
            when Ast::MethodCall then emit_method_call(emit, node, locals)
            else
              "/* UNHANDLED: #{node.class.name} */ static_cast<BasicObject*>(&NIL_INSTANCE)"
            end
          end

          def self.emit_method_call(emit, node, locals)
            recv = node.receiver_node
            name = node.name
            args = (node.arg_nodes || []).map { |a| emit_expr(emit, a, locals) }
            if recv
              recv_s = emit_expr(emit, recv, locals)
              method_name = OP_NAMES[name] || "m_#{name}"
              "#{recv_s}->#{method_name}(#{args.join(", ")})"
            elsif name == :puts
              "ruby_puts(#{args.join(", ")})"
            else
              "this->#{name}(#{args.join(", ")})"
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
