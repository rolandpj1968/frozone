require_relative 'node'

module Frozone
  module Ast
    class BreakException < StandardError
      attr_reader :value
      attr_accessor :from_block
      def initialize(value) = @value = value
    end

    class Break < Node
      def initialize(value_node)
        @value_node = check_nil_or_type("value_node", value_node, Node)
      end

      def evaluate(context)
        value = @value_node ? @value_node.evaluate(context) : Vm::NilObject::NIL
        raise BreakException.new(value)
      end
    end
  end
end
