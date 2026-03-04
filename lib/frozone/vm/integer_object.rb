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

      def value = @value

      def to_s = @value.to_s

      class << self
        def check(v)
          raise 'Intrinsic requires IntegerObject' unless v.is_a?(IntegerObject)
          v
        end

        #
        # Intrinsics
        #

        def add(v1, v2)
          new(check(v1).value + check(v2).value)
        end
      end
    end
  end
end

