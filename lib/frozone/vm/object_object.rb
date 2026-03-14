module Frozone
  module Vm
    class ObjectObject
      @@bootstrapping = true

      def self.end_bootstrap! = @@bootstrapping = false

      attr_reader :class_object, :eigenclass

      attr_reader :frozen_object

      def initialize(class_object)
        unless @@bootstrapping || class_object.is_a?(ClassObject)
          raise "ObjectObject class_object must be a ClassObject"
        end
        @class_object = class_object
        @instance_variables = {}
        @eigenclass = nil
        @frozen_object = false
      end

      def freeze_object!
        @frozen_object = true
        # Also freeze the singleton class if it exists
        @eigenclass&.freeze_object!
        self
      end

      def frozen_object? = @frozen_object

      def lookup_class = @eigenclass || @class_object

      def singleton_class
        unless @eigenclass
          # For ClassObjects, singleton class inherits from the superclass's singleton class
          sc_superclass =
            if is_a?(ClassObject) && respond_to?(:superclass) && superclass
              superclass.singleton_class
            else
              @class_object
            end
          @eigenclass = ClassObject.new(nil, nil, sc_superclass)
          @eigenclass.instance_variable_set(:@is_singleton_class, true)
          @eigenclass.instance_variable_set(:@singleton_of, self)
          # Propagate frozen state to newly-created singleton class
          @eigenclass.freeze_object! if @frozen_object
        end
        @eigenclass
      end

      # Returns a method defined directly on the eigenclass (if one exists).
      def eigenclass_method(name) = @eigenclass&.get_method(name)

      def define_singleton_method(name, unbound_method)
        singleton_class.set_method(name, unbound_method)
      end

      def lookup_instance_method(name)
        method = lookup_class.lookup_method(name)
        return method unless method.nil?
        # For ClassObjects, also walk superclass eigenclasses for inherited class methods
        if is_a?(ClassObject) && respond_to?(:superclass)
          c = superclass
          while c
            m = c.eigenclass_method(name)
            return m unless m.nil?
            c = c.respond_to?(:superclass) ? c.superclass : nil
          end
        end
        nil
      end

      # Shared dispatch: look up and invoke a method on self by Symbol name.
      # Falls back to method_missing if the method is not found.
      # private_ok: true when called with implicit receiver (no explicit receiver in source)
      # implicit_self: true for bare-word calls (no receiver) — raises NameError vs NoMethodError on miss
      def dispatch(context, name, args, kw_args, block = nil, private_ok: false, implicit_self: false)
        method = lookup_instance_method(name)
        unless method.nil?
          case method.visibility
          when :private
            unless private_ok
              raise FrozoneException.make(:NoMethodError, "private method '#{name}' called for an instance of #{@class_object.name}")
            end
          when :protected
            caller_class = context&.frame&.the_self&.class_object
            unless subclass_of?(caller_class, @class_object)
              raise FrozoneException.make(:NoMethodError, "protected method '#{name}' called for an instance of #{@class_object.name}")
            end
          end
          return method.invoke(context, self, args, kw_args, block)
        end

        mm = lookup_instance_method(:method_missing)
        raise "BUG: method_missing not defined on #{@class_object.name}" if mm.nil?
        # Track whether this is an implicit-self call so method_missing can raise NameError vs NoMethodError
        prev = Fiber[:mm_implicit_self]
        Fiber[:mm_implicit_self] = implicit_self
        begin
          mm.invoke(context, self, [SymbolObject.from(name)] + args, kw_args, block)
        ensure
          Fiber[:mm_implicit_self] = prev
        end
      end

      def inspect = "#<#{self.class.name}>"

      def ivar_defined?(name)
        @instance_variables.key?(name)
      end

      def get_ivar(name)
        @instance_variables.fetch(name, NilObject::NIL)
      end

      def set_ivar(name, value)
        if @frozen_object
          type_name = is_a?(ModuleObject) ? (is_a?(ClassObject) ? "Class" : "Module") : (@class_object&.name&.to_s || "Object")
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{type_name}: #{inspect_for_error}", receiver: self)
        end
        @instance_variables[name] = value
      end

      def inspect_for_error
        "#<#{@class_object&.name}>"
      end

      def truthy?
        !equal?(FalseObject::FALSE) && !equal?(NilObject::NIL)
      end

      private

      # Is klass the same as or a subclass of ancestor?
      def subclass_of?(klass, ancestor)
        c = klass
        while c
          return true if c.equal?(ancestor)
          c = c.is_a?(ClassObject) ? c.superclass : nil
        end
        false
      end
    end
  end
end
