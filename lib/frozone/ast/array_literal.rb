require_relative 'node'
require_relative '../vm/array_object'

module Frozone
  module Ast
    class ArrayLiteral < Node
      def initialize(element_nodes)
        @element_nodes = check_array_type("element_nodes", element_nodes, Node)
      end

      def to_s = "arr(TODO)"

      def evaluate(context) = Vm::ArrayObject.new(@element_nodes.map { |e| e.evaluate(context) })
    end
  end
end
