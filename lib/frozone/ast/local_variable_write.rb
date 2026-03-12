require_relative 'node'

module Frozone
  module Ast
    class LocalVariableWrite < Node
      def initialize(name, depth, value_node)
        @name = name
        @depth = depth
        @value_node = value_node
      end

      def to_s = "local=(#{@name}, #{@depth}, #{@value_node})"

      def evaluate(context)
        value = @value_node.evaluate(context)
        context.frame.frame_at_depth(@depth).set_local(@name, value)
        value
      end
    end
  end
end
