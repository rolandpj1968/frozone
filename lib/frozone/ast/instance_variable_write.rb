require_relative 'node'

module Frozone
  module Ast
    class InstanceVariableWrite < Node
      def initialize(name, value_node)
        @name = check_type("name", name, Symbol)
        @value_node = check_type("value_node", value_node, Node)
      end

      def to_s = "ivar=(#{@name}, #{@value_node})"

      def evaluate(context)
        value = @value_node.evaluate(context)
        context.frame.the_self.set_ivar(@name, value)
        value
      end
    end
  end
end
