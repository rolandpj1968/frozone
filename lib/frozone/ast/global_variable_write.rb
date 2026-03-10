require_relative 'node'
require_relative '../vm/globals'

module Frozone
  module Ast
    class GlobalVariableWrite < Node
      def initialize(name, value_node)
        @name = check_type("name", name, Symbol)
        @value_node = check_type("value_node", value_node, Node)
      end

      def to_s = "gvar(#{@name}) = #{@value_node}"

      def evaluate(context)
        value = @value_node.evaluate(context)
        store(context, value)
      end

      def store(context, value)
        Vm::GLOBALS[@name] = value
        value
      end
    end
  end
end
