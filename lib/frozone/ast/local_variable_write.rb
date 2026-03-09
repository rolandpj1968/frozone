require_relative 'node'

module Frozone
  module Ast
    class LocalVariableWrite < Node
      def initialize(name, depth, value_node)
        @name = check_type("name", name, Symbol)
        @depth = check_type("depth", depth, Integer)
        @value_node = check_type("value_node", value_node, Node)
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
