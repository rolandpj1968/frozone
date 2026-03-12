module Frozone
  module Vm
    # Wraps a Frozone method as an UnboundMethod VM object.
    class UnboundMethodObject < ObjectObject
      attr_reader :raw_method, :unbound_name, :unbound_owner

      def initialize(method, name, owner)
        super(Core.unbound_method_class || Core::OBJECT_CLASS)
        @raw_method = method
        @unbound_name = name
        @unbound_owner = owner
      end
    end
  end
end
