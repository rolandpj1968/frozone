require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class StringObject < ObjectObject
      attr_accessor :raw

      def initialize(value, frozen: false)
        raise "StringObject must have an String value" unless value.is_a?(String)

        super(Core::STRING_CLASS)

        @raw = value.freeze
        @frozen = frozen
      end

      def frozen? = @frozen

      def to_s = @raw
    end
  end
end
