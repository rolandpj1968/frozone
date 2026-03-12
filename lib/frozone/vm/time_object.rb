require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class TimeObject < ObjectObject
      attr_reader :raw

      def initialize(time)
        super(Core::OBJECT_CLASS.get_constant(:Time))
        @raw = time
      end

      def truthy? = true
    end
  end
end
