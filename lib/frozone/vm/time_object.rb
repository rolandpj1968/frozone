require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class TimeObject < ObjectObject
      def initialize(time)
        super(Core::OBJECT_CLASS.get_constant(:Time))
        @time = time
      end

      def raw = @time
      def truthy? = true
    end
  end
end
