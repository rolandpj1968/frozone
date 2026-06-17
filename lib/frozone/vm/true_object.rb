require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class TrueObject < ObjectObject
      def initialize
        super(Core::TRUE_CLASS_CLASS)
        @frozen_object = true
      end

      # Global singleton object
      private_class_method :new

      def raw = true
      def truthy? = true  # explicit (Phase 2 fusion :self-only filter)

      TRUE = new
    end
  end
end
