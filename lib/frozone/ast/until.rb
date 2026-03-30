require_relative 'node'

module Frozone
  module Ast
    class Until < Node
      def initialize(condition_node, body_node, begin_modifier: false)
        @condition_node = condition_node
        @body_node = body_node
        @begin_modifier = begin_modifier
      end

      def children = [@condition_node, @body_node]

      def to_s
        "until(#{@condition_node}, #{@body_node})"
      end

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
            begin
              @body_node.evaluate(context)
            rescue NextException
              next
            rescue RedoException
              redo
            rescue BreakException => e
              raise if e.from_block
              return e.value
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
