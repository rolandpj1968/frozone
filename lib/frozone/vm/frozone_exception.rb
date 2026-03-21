module Frozone
  module Vm
    # Host-Ruby wrapper around a Frozone VM exception object.
    # Lets rescue distinguish real VM exceptions from control-flow exceptions
    # (ReturnException, NextException, RedoException) which must never be caught
    # by user-level rescue clauses.
    class FrozoneException < StandardError
      attr_reader :vm_object   # the Frozone VM exception object (e.g. RuntimeError instance)

      def frozone_class_name = @vm_object.is_a?(ObjectObject) ? @vm_object.class_object&.name : nil

      def initialize(vm_object, message)
        @vm_object = vm_object
        super(message)
      end

      def self.make(class_name, message, name: nil, receiver: nil)
        # Support "Errno__ENOENT" style names as namespace separators (Errno::ENOENT)
        parts = class_name.to_s.split('__').map(&:to_sym)
        exc_class = parts.reduce(Core::OBJECT_CLASS) { |scope, const| scope&.get_constant(const) }
        # NOTE: tap would be awkward here — exc_obj is used as an argument to new(), not returned,
        # and the conditional set_ivar guards make the block body non-trivial.
        exc_obj = exc_class ? ObjectObject.new(exc_class) : NilObject::NIL
        unless exc_obj.is_a?(NilObject)
          exc_obj.set_ivar(:@message, StringObject.new(message))
          exc_obj.set_ivar(:@name, SymbolObject.from(name)) if name
          exc_obj.set_ivar(:@receiver, receiver) if receiver
        end
        new(exc_obj, message)
      end

      # Wrap a plain MRI Ruby exception as a proper Frozone VM exception object.
      # Falls back to RuntimeError if the MRI exception class is not defined in Frozone.
      def self.wrap_mri(e)
        return e.vm_object if e.is_a?(FrozoneException)
        # Try to find the VM class by traversing the qualified MRI class name (e.g. Encoding::CompatibilityError)
        parts = e.class.name&.split('::')&.map(&:to_sym) || [:RuntimeError]
        exc_class = parts.reduce(Core::OBJECT_CLASS) { |scope, const| scope&.get_constant(const) }
        exc_class ||= Core::OBJECT_CLASS.get_constant(:RuntimeError)
        return NilObject::NIL unless exc_class
        ObjectObject.new(exc_class).tap { |exc_obj| exc_obj.set_ivar(:@message, StringObject.new(e.message)) }
      end
    end
  end
end
