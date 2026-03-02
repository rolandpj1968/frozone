module Frozone
  module Ast
    class Or
      def initialize(left_node, right_node)
        @left_node = left_node
        @right_node = right_node
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
