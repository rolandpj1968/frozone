require_relative 'node'

module Frozone
  module Ast
    # Raised to skip the rest of a block/loop body iteration; caught by
    # BlockObject#invoke or While/Until#evaluate.
    class NextException < StandardError
      attr_reader :value
      def initialize(value) = @value = value
    end

    class Next < Node
      def initialize(value_node)
        @value_node = value_node
      end

      def children = [@value_node].compact

      def evaluate(context)
        value = @value_node ? @value_node.evaluate(context) : Vm::NilObject::NIL
        raise NextException.new(value)
      end
    end
  end
end
