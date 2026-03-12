require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class IntegerObject < ObjectObject
      def initialize(value)
        raise "IntegerObject must have an Integer value" unless value.is_a?(Integer)

        super(Core::INTEGER_CLASS)

        @value = value
      end

      def to_s = @value.to_s

      def raw = @value
    end
  end
end
