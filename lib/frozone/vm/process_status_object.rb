require_relative 'object_object'
require_relative 'core'

module Frozone
  module Vm
    class ProcessStatusObject < ObjectObject
      attr_reader :native_status

      def initialize(native_status)
        super(Core.process_status_class)
        @native_status = native_status
      end

      def truthy? = true
    end
  end
end
