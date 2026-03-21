require_relative 'node'

module Frozone
  module Ast
    class BreakException < StandardError
      attr_reader :value, :method_frame
      attr_accessor :from_block, :break_enclosing_frame
      def initialize(value, method_frame = nil)
        @value = value
        @method_frame = method_frame
      end
    end

    class Break < Node
      def initialize(value_node)
        @value_node = value_node
      end

      def evaluate(context)
        value = @value_node ? @value_node.evaluate(context) : Vm::NilObject::NIL
        # When break runs inside a Thread body (outside any while/until loop), it raises
        # LocalJumpError. While/until loops temporarily clear thread_boundary so break
        # inside them raises BreakException and is caught by the loop as expected.
        if context.frame.thread_boundary
          raise Vm::FrozoneException.make(:LocalJumpError, "break from proc-closure")
        end
        raise BreakException.new(value, context.frame.method_frame)
      end
    end
  end
end
