require_relative 'node'

module Frozone
  module Ast
    class BreakException < StandardError
      attr_reader :value, :method_frame
      attr_accessor :from_block
      def initialize(value, method_frame = nil)
        @value = value
        @method_frame = method_frame
      end
    end

    class Break < Node
      def initialize(value_node)
        @value_node = check_nil_or_type("value_node", value_node, Node)
      end

      def evaluate(context)
        value = @value_node ? @value_node.evaluate(context) : Vm::NilObject::NIL
        raise BreakException.new(value, context.frame.method_frame)
      end
    end
  end
end
