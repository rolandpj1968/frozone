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

      def lookup_method(name)
        @eigenclass.lookup_method(name)
      end

      def truthy?
        !equal?(FalseObject::FALSE) && !equal?(NilObject::NIL)
      end
    end
  end
end
