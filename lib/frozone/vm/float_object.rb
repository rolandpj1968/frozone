require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class FloatObject < ObjectObject
      def initialize(value)
        super(Core::OBJECT_CLASS.get_constant(:Float))
        @value = value
      end

      def raw = @value
      def truthy? = true
    end
  end
end
