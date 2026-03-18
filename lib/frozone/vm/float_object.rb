require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class FloatObject < ObjectObject
      attr_reader :raw

      def initialize(value)
        super(Core::OBJECT_CLASS.get_constant(:Float))
        @raw = value
        @frozen_object = true
      end

      def truthy? = true
    end
  end
end
