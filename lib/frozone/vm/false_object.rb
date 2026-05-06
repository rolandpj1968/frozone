require_relative 'core'
require_relative 'object_object'

module Frozone
  module Vm
    class FalseObject < ObjectObject
      def initialize
        super(Core::FALSE_CLASS_CLASS)
        @frozen_object = true
      end

      # Global singleton object
      private_class_method :new

      def raw = false
      def to_s = "false"
      def inspect_for_error = "false"
      # Phase 2 fusion :self-only filter excludes ObjectObject's
      # `def truthy? = !equal?(FalseObject::FALSE) && !equal?(NilObject::NIL)`
      # from the runtime FalseClass overlay. Define explicitly here so
      # the compiled FalseClass has m_truthy_q without needing to walk
      # to the (filtered-out) Frozone_Vm_ObjectObject parent. NilObject
      # defines its own already; TrueObject's inherited-truthy? would
      # correctly return true but for symmetry we'd want it explicit too.
      def truthy? = false

      FALSE = new
    end
  end
end
