module Frozone
  module Vm
    # Host-Ruby wrapper around a Frozone VM exception object.
    # Lets rescue distinguish real VM exceptions from control-flow exceptions
    # (ReturnException, NextException, RedoException) which must never be caught
    # by user-level rescue clauses.
    class FrozoneException < StandardError
      attr_reader :vm_object   # the Frozone VM exception object (e.g. RuntimeError instance)

      def initialize(vm_object, message)
        @vm_object = vm_object
        super(message)
      end

      def self.make(class_name, message)
        exc_class = Core::OBJECT_CLASS.get_constant(class_name)
        exc_obj = exc_class ? ObjectObject.new(exc_class) : NilObject::NIL
        exc_obj.set_ivar(:@message, StringObject.new(message)) unless exc_obj.is_a?(NilObject)
        new(exc_obj, message)
      end
    end
  end
end
