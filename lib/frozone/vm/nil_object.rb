require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class NilObject < ObjectObject
      def initialize
        super(Core::NIL_CLASS_CLASS)
        @frozen_object = true
      end

      # Global singleton object
      private_class_method :new

      def raw = nil
      def truthy? = false

      NIL = new
    end
  end
end
