require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class ArrayObject < ObjectObject
      def initialize(elements, class_obj = nil)
        raise "ArrayObject must have an Array elements" unless elements.is_a?(Array)

        super(class_obj || Core::ARRAY_CLASS)

        @elements = elements
      end

      def [](index) = @elements[index]

      def []=(index, value)
        @elements[index] = value
      end

      def push(value) = @elements.push(value)
      def length = @elements.length

      def to_s = "[#{@elements.join(', ')}]"

      def raw = @elements
    end
  end
end

