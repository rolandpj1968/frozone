require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class NilObject < ObjectObject
      def initialize
        super(Core::NIL_CLASS_CLASS)
      end

      # Global singleton object
      private_class_method :new

      def to_s = "nil"

      NIL = new
    end
  end
end

