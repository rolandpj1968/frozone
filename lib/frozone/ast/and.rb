require_relative 'node'

module Frozone
  module Ast
    class And < Node
      def initialize(left_node, right_node)
        @left_node = left_node
        @right_node = right_node
      end

      def children = [@left_node, @right_node]

      def to_s
        "and(#{@left_node}, #{@right_node})"
      end

      def evaluate(context)
        left_value = @left_node.evaluate(context)
        return left_value unless left_value.truthy?

        @right_node.evaluate(context)
      end
    end
  end
end
