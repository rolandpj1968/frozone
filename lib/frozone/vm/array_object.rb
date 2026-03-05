require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class ArrayObject < ObjectObject
      def initialize(elements)
        raise "ArrayObject must have an Array elements" unless elements.is_a?(Array)

        super(Core::ARRAY_CLASS)

        @elements = elements
      end

      def to_s = "[#{@elements.join(', ')}]"
    end
  end
end

