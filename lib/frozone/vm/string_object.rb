require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class StringObject < ObjectObject
      attr_accessor :raw

      def initialize(value, frozen: false, class_obj: nil)
        raise "StringObject must have an String value" unless value.is_a?(String)

        super(class_obj || Core::STRING_CLASS)

        @raw = value.frozen? ? value.dup : value
        @frozen_object = frozen
      end

      def frozen? = @frozen_object

      def to_s = @raw
    end
  end
end
