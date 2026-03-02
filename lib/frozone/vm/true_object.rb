require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class TrueObject < ObjectObject
      def initialize
        super(Core::TRUE_CLASS_CLASS)
      end

      # Global singleton object
      private_class_method :new

      def to_s = "true"

      TRUE = new
    end
  end
end

