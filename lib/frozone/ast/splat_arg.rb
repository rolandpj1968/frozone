require_relative 'node'

module Frozone
  module Ast
    # Represents *expr in a method call argument list
    class SplatArg < Node
      def initialize(value_node)
        @value_node = check_nil_or_type("value_node", value_node, Node)
      end

      def evaluate(context)
        return Vm::ArrayObject.new([]) if @value_node.nil?
        val = @value_node.evaluate(context)
        val.is_a?(Vm::ArrayObject) ? val : Vm::ArrayObject.new([val])
      end
    end
  end
end
