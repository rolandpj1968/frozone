require_relative 'node'

module Frozone
  module Ast
    class InstanceVariableWrite < Node
      def initialize(name, value_node)
        @name = name
        @value_node = value_node
      end

      def children = [@value_node]
      def to_s = "ivar=(#{@name}, #{@value_node})"

      def evaluate(context)
        value = @value_node.evaluate(context)
        store(context, value)
      end

      def store(context, value)
        context.frame.the_self.set_ivar(@name, value)
        value
      end
    end
  end
end
