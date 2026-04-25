# Box-first C++ backend — statement-position writers.
#
# Multi-line / control-flow emission. Every method here mutates the
# Emitter buffer via `emit.line` / `emit.indented`. For inline
# expression strings, calls into `emit.cpp.from_*` (the pure side).
#
# Entry points:
#   write_body(emit, body, locals:, last_is_return:)  — emit a sequence
#   write_stmt(emit, node, locals)                    — emit one statement
#
# All other write_* methods are dispatch helpers for specific shapes
# (write_if_stmt, write_while_stmt, write_local_write_stmt, etc.).

module Frozone
  module Compiler
    module Backend
      module CppBox
        class ExprEmitter
          # `last_is_return` (true for method bodies) wraps the final
          # statement in `return ...;` if it's an expression — Ruby's
          # implicit return semantics.
          def self.write_body(emit, body, locals:, last_is_return: false)
            stmts = body.is_a?(Ast::Sequence) ? body.nodes : [body]
            stmts.each_with_index do |n, i|
              last = i == stmts.length - 1
              if last && last_is_return && Cpp.expression_node?(n)
                emit.line "return #{emit.cpp.from_expr(n, locals)};"
              else
                write_stmt(emit, n, locals)
              end
            end
          end

          def self.write_stmt(emit, node, locals)
            case node
            when Ast::Return
              emit.line "return #{emit.cpp.from_expr(node.value_node, locals)};"
            when Ast::If
              write_if_stmt(emit, node, locals)
            when Ast::While
              write_while_stmt(emit, node, locals)
            when Ast::LocalVariableWrite
              write_local_write_stmt(emit, node, locals)
            when Ast::MethodCall
              if node.name == :times && node.receiver_node && node.block_node
                write_times_block(emit, node, locals)
              else
                emit.line "#{emit.cpp.from_expr(node, locals)};"
              end
            when Ast::Sequence
              node.nodes.each { |n| write_stmt(emit, n, locals) }
            else
              emit.line "#{emit.cpp.from_expr(node, locals)};"
            end
          end

          def self.write_if_stmt(emit, node, locals)
            cond = emit.cpp.from_expr(node.pred_node, locals)
            emit.line "if (truthy(#{cond})) {"
            emit.indented do
              write_body(emit, node.then_node, locals: locals) if node.then_node
            end
            if node.else_node
              emit.line "} else {"
              emit.indented { write_body(emit, node.else_node, locals: locals) }
            end
            emit.line "}"
          end

          def self.write_while_stmt(emit, node, locals)
            emit.line "while (truthy(#{emit.cpp.from_expr(node.condition_node, locals)})) {"
            emit.indented do
              write_body(emit, node.body_node, locals: locals) if node.body_node
            end
            emit.line "}"
          end

          def self.write_local_write_stmt(emit, node, locals)
            rhs = emit.cpp.from_expr(node.value_node, locals)
            if locals.include?(node.name.to_s)
              emit.line "#{node.name} = #{rhs};"
            else
              locals << node.name.to_s
              emit.line "BasicObject* #{node.name} = #{rhs};"
            end
          end

          # `recv.times { |i| body }` → C++ for-loop. Mirrors mainline's
          # special-case desugaring. recv is a BasicObject*; we extract
          # raw_ via static_cast<Integer*>, except when recv is a literal
          # (then use the int directly).
          def self.write_times_block(emit, node, locals)
            blk = node.block_node
            var = (blk.required_params || [])[0] || :_i
            locals << var.to_s
            recv_node = node.receiver_node
            count = if recv_node.is_a?(Ast::IntegerLiteral)
                      "#{recv_node.value.raw}LL"
                    else
                      "static_cast<Integer*>(#{emit.cpp.from_expr(recv_node, locals)})->raw_"
                    end
            emit.line "for (int64_t #{var} = 0; #{var} < #{count}; #{var}++) {"
            emit.indented { write_body(emit, blk.body, locals: locals) }
            emit.line "}"
          end
        end
      end
    end
  end
end
