require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class ArrayObject < ObjectObject
      # Vm::ArrayObject is a thin wrapper around a host MRI `Array` (the
      # `@elements` ivar). All Ruby-level semantics — `[]`, `[]=`, `push`,
      # `length`, `each`, `to_s`, etc. — are defined ONCE in
      # `lib/core/4.0/array.rb`. This class exposes only `#raw` so that
      # MRI bridges can explicitly cross the host membrane via `v.raw.X`.
      # See `docs/design.md`.

      def initialize(elements, class_obj = nil)
        raise "ArrayObject must have an Array elements" unless elements.is_a?(Array)

        super(class_obj || Core::ARRAY_CLASS)

        @elements = elements
      end

      def raw = @elements
    end
  end
end
