require_relative 'node'

module Frozone
  module Ast
    class Until < Node
      attr_reader :condition_node, :body_node
      def initialize(condition_node, body_node, begin_modifier: false)
        @condition_node = condition_node
        @body_node = body_node
        @begin_modifier = begin_modifier
      end

      def children = [@condition_node, @body_node]

      def to_s = "until(#{@condition_node}, #{@body_node})"

      def evaluate(context)
        first = @begin_modifier
        # Temporarily clear thread_boundary so break inside the loop raises BreakException
        # (caught by the loop itself) rather than LocalJumpError (thread-boundary behavior).
        frame = context.frame
        old_thread_boundary = frame.thread_boundary
        frame.thread_boundary = false if old_thread_boundary
        begin
          until !first && @condition_node.evaluate(context).truthy?
            first = false
            # State-flag instead of `next`/`redo` inside rescue — same
            # reasoning as Ast::While. See while.rb for details.
            iteration_done = false
            until iteration_done
              iteration_done = true
              begin
                @body_node.evaluate(context)
              rescue NextException
                # iteration_done stays true
              rescue RedoException
                iteration_done = false
              rescue BreakException => e
                raise if e.from_block
                return e.value
              end
            end
          end
          Vm::NilObject::NIL
        ensure
          frame.thread_boundary = old_thread_boundary
        end
      end
    end
  end
end
