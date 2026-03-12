require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class StringObject < ObjectObject
      def initialize(value, frozen: false)
        raise "StringObject must have an String value" unless value.is_a?(String)

        super(Core::STRING_CLASS)

        @value = value.freeze
        @frozen = frozen
      end

      def frozen? = @frozen

      def raw = @value

      def to_s = @value
    end
  end
end
