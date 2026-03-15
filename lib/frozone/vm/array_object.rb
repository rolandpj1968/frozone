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

      def push(value)
        raise FrozoneException.make(:FrozenError, "can't modify frozen Array: #{array_inspect_for_error}", receiver: self) if frozen_object?
        @elements.push(value)
      end
      def length = @elements.length

      def to_s = "[#{@elements.join(', ')}]"

      def raw = @elements

      private

      def array_inspect_for_error
        ctx = Fiber[:context]
        "[#{@elements.map { |e| ctx ? begin; e.dispatch(ctx, :inspect, [], {}, nil, private_ok: true).raw; rescue StandardError; e.to_s; end : e.to_s }.join(', ')}]"
      end
    end
  end
end
