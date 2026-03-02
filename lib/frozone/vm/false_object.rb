require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class FalseObject < ObjectObject
      def initialize
        super(Core::FALSE_CLASS_CLASS)
      end

      # Global singleton object
      private_class_method :new

      def to_s = "false"

      FALSE = new
    end
  end
end

