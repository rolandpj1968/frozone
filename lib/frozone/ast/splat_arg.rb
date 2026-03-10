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
        return Vm::ArrayObject.new([]) if val.is_a?(Vm::NilObject)
        return val if val.is_a?(Vm::ArrayObject)
        # Try to_ary first (implicit conversion), then to_a (explicit)
        if val.class_object.lookup_method(:to_ary)
          result = val.dispatch(context, :to_ary, [], {})
          return result if result.is_a?(Vm::ArrayObject)
        end
        if val.class_object.lookup_method(:to_a)
          result = val.dispatch(context, :to_a, [], {})
          return result if result.is_a?(Vm::ArrayObject)
        end
        Vm::ArrayObject.new([val])
      end
    end
  end
end
