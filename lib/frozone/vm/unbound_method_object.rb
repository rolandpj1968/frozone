module Frozone
  module Vm
    # Wraps a Frozone method as an UnboundMethod VM object.
    class UnboundMethodObject < ObjectObject
      def initialize(method, name, owner)
        super(Core.unbound_method_class || Core::OBJECT_CLASS)
        @method = method
        @unbound_name = name
        @owner = owner
      end

      def raw_method = @method
      def unbound_name = @unbound_name
      def unbound_owner = @owner
    end
  end
end
