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
    end
  end
end
