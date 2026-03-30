require_relative 'node'
require_relative '../vm/array_object'

module Frozone
  module Ast
    class ArrayLiteral < Node
      def initialize(element_nodes)
        @element_nodes = element_nodes
      end

      def children = @element_nodes

      def to_s = "arr(TODO)"

      def evaluate(context)
        elements = @element_nodes.flat_map do |e|
          e.is_a?(SplatArg) ? e.evaluate(context).raw : e.evaluate(context)
        end
        Vm::ArrayObject.new(elements)
      end
    end
  end
end
