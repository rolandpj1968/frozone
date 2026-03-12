require_relative 'node'
require_relative '../vm/module_object'

module Frozone
  module Ast
    class ConstantWrite < Node
      def initialize(name, value_node)
        @name = check_type("name", name, Symbol)
        @value_node = check_type("value_node", value_node, Node)
      end

      def to_s = "con=(#{@name}, #{@value_node})"

      def evaluate(context) = store(context, @value_node.evaluate(context))

      def store(context, value)
        context.scopes.last.set_constant(@name, value)
        value
      end
    end
  end
end
