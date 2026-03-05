require_relative 'node'

module Frozone
  module Ast
    class Or < Node
      def initialize(left_node, right_node)
        @left_node = check_type("left_node", left_node, Node)
        @right_node = check_type("right_node", right_node, Node)
      end

      def to_s
        "or(#{@left_node}, #{@right_node})"
      end

      def evaluate(context)
        left_value = @left_node.evaluate(context)
        return left_value if left_value.truthy?

        @right_node.evaluate(context)
      end
    end
  end
end
