require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class IntegerObject < ObjectObject
      attr_reader :raw

      def initialize(value)
        raise "IntegerObject must have an Integer value" unless value.is_a?(Integer)

        super(Core::INTEGER_CLASS)

        @raw = value
        @frozen_object = true
      end

      def to_s = @raw.to_s
      # Post Vm::IOObject fusion: Vm-interpreter-evaluated arithmetic
      # results (e.g. block bodies like `{ |x| x * 10 }`) flow back
      # through compiled runtime Array#inspect → element.inspect.
      # Without this shim, the default `#<Frozone_Vm_IntegerObject>`
      # falls out. Forward to to_s for the Integer format. Future
      # Vm::IntegerObject ≡ Integer fusion would replace this with
      # direct runtime Integer dispatch.
      def inspect = @raw.to_s
      def inspect_for_error = @raw.inspect

      # Marshal support: serialize just the raw integer and restore with the
      # live Core::INTEGER_CLASS so deserialized objects dispatch correctly.
      def marshal_dump = @raw

      def marshal_load(data)
        @raw = data
        @class_object = Core::INTEGER_CLASS
        @frozen_object = true
        @instance_variables_hash = {}
        @eigenclass = nil
      end
    end
  end
end
