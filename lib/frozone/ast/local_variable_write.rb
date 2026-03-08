require_relative 'node'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class LocalVariableWrite < Node
      def initialize(name, depth, value_node)
        @name = check_type("name", name, Vm::SymbolObject)
        @depth = check_type("depth", depth, Integer)
        @value_node = check_type("value_node", value_node, Node)
      end

      def to_s = "local=(#{@name.raw}, #{@depth}, #{@value_node})"

      # TODO depth
      def evaluate(context)
        value = @value_node.evaluate(context)
        context.frame.set_local(@name, value)
        value
      end
    end
  end
end
