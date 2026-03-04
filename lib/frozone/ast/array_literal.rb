require_relative '../vm/array_object'

module Frozone
  module Ast
    class ArrayLiteral
      attr_reader :elements

      def initialize(elements)
        raise "ArrayLiteral elements must be an Array not #{elements.class}" unless elements.is_a?(Array)
        @elements = elements
      end

      def to_s = "arr()"

      def evaluate(context) = Vm::ArrayObject.new(elements.map { |e| e.evaluate(context) })
    end
  end
end
