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
      def inspect_for_error = @raw.inspect
    end
  end
end
