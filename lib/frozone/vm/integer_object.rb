require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class IntegerObject < ObjectObject
      # Thin wrapper around a host MRI `Integer` — see docs/design.md.
      # Ruby semantics live in lib/core/4.0/integer.rb; bridges cross the
      # host membrane via `#raw`.

      attr_reader :raw

      def initialize(value)
        raise "IntegerObject must have an Integer value" unless value.is_a?(Integer)

        super(Core::INTEGER_CLASS)

        @raw = value
        @frozen_object = true
      end

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
