module Frozone
  module Vm
    class ObjectObject
      def initialize(class_object)
        unless class_object.is_a?(ClassObject) || (class_object.nil? && Core.class_class.nil?)
          raise "ObjectObject class_object must be a ClassObject"
        end
        @class_object = class_object
        @instance_variables = {}
        @eigenclass = class_object # promoted to singleton class at first singleton method def
      end

      #def class_object = @class_object

      def create_singleton_class
        raise "bollocks"
        # TODO - this is bollocks
        if @eige.is_a?(@class_object)
          # TODO - the namespace is probs the same as for this Object? Will affect constant lookup order etc.
          @eigenclass = ClassObject.new(name = nil, namespace = nil, class_object)
        end
      end

      # TODO - this is probs not necessary cos eigenclass will be created first
      def define_singleton_method(name, unbound_method)
        create_singleton_class
        @eigenclass.set_method(name, unbound_method)
      end

      def lookup_instance_method(name)
        @eigenclass.lookup_method(name)
      end

      # Shared dispatch: look up and invoke a method on self by SymbolObject name.
      # Raises if the method is not found (missing_method is not yet implemented).
      def dispatch(context, name, args, kw_args)
        method = lookup_instance_method(name)
        # TODO - this is a runtime exception, not an assert
        raise "method :#{name.raw} not found - not yet doing missing_method" if method.nil?
        method.invoke(context, self, args, kw_args)
      end

      def get_ivar(name)
        @instance_variables.fetch(name, NilObject::NIL)
      end

      def set_ivar(name, value)
        @instance_variables[name] = value
      end

      def truthy?
        !equal?(FalseObject::FALSE) && !equal?(NilObject::NIL)
      end

      #
      # For Hash emulation using "native" Hash
      #
      # TODO work out how to do this properly - we need to call :hash, :eql? properly, but don't have the context
      #
      # def hash = self.send(:hash)
      # def eql?(v) = self.send(:eql?(v))
    end
  end
end
