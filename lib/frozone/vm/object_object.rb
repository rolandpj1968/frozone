module Frozone
  module Vm
    class ObjectObject
      @@bootstrapping = true

      def self.end_bootstrap! = @@bootstrapping = false

      def initialize(class_object)
        unless @@bootstrapping || class_object.is_a?(ClassObject)
          raise "ObjectObject class_object must be a ClassObject"
        end
        @class_object = class_object
        @instance_variables = {}
        @eigenclass = class_object # promoted to singleton class at first singleton method def
      end

      def class_object = @class_object

      def create_singleton_class
        return unless @eigenclass.equal?(@class_object)
        @eigenclass = ClassObject.new(nil, nil, @class_object)
      end

      def define_singleton_method(name, unbound_method)
        create_singleton_class
        @eigenclass.set_method(name, unbound_method)
      end

      def lookup_instance_method(name)
        @eigenclass.lookup_method(name)
      end

      # Shared dispatch: look up and invoke a method on self by Symbol name.
      # Falls back to method_missing if the method is not found.
      def dispatch(context, name, args, kw_args)
        method = lookup_instance_method(name)
        return method.invoke(context, self, args, kw_args) unless method.nil?

        mm = lookup_instance_method(:method_missing)
        raise "BUG: method_missing not defined on #{@class_object.name}" if mm.nil?
        mm.invoke(context, self, [name] + args, kw_args)
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
