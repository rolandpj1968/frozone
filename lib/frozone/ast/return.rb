require_relative 'node'

module Frozone
  module Ast
    # Raised to unwind the call stack on `return`; caught by Method#invoke
    # only when method_frame matches the frame that should handle this return.
    class ReturnException < StandardError
      attr_reader :value, :method_frame
      def initialize(value, method_frame) = (@value = value; @method_frame = method_frame)
    end

    class Return < Node
      def initialize(value_node)
        @value_node = value_node
      end

      def evaluate(context)
        value = @value_node ? @value_node.evaluate(context) : Vm::NilObject::NIL
        # When return runs inside a Thread body, it raises LocalJumpError (catchable by guest
        # rescue inside the block), simulating the cross-thread boundary of real Ruby threading.
        if context.frame.thread_boundary
          exc = Vm::FrozoneException.make(:LocalJumpError, "unexpected return")
          exc.vm_object.set_ivar(:@exit_value, value)
          raise exc
        end
        raise ReturnException.new(value, context.frame.method_frame)
      end
    end
  end
end
