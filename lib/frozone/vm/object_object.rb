module Frozone
  module Vm
    class ObjectObject
      @@bootstrapping = true

      def self.end_bootstrap! = @@bootstrapping = false

      attr_reader :class_object, :eigenclass
      attr_accessor :class_object

      attr_reader :frozen_object
      attr_reader :instance_variables_hash

      def initialize(class_object)
        unless @@bootstrapping || class_object.is_a?(ClassObject)
          raise "ObjectObject class_object must be a ClassObject"
        end
        @class_object = class_object
        @instance_variables_hash = {}
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

      # Copy base ObjectObject fields from source into self (used by dup/clone).
      # Sets eigenclass and frozen state directly — this is intentionally internal.
      def copy_fields_from(source, eigenclass: nil, frozen: false)
        @instance_variables_hash = source.instance_variables_hash.dup
        @eigenclass = eigenclass
        @frozen_object = frozen
        self
      end

      def lookup_class = @eigenclass || @class_object

      def singleton_class
        unless @eigenclass
          # For ClassObjects, singleton class inherits from the superclass's singleton class
          sc_superclass =
            if is_a?(ClassObject) && superclass
              superclass.singleton_class
            else
              @class_object
            end
          @eigenclass = ClassObject.new(nil, nil, sc_superclass)
          @eigenclass.is_singleton_class = true
          @eigenclass.singleton_of = self
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
        # For ClassObjects: eigenclass chain takes priority over Class instance methods.
        # Own eigenclass → superclass eigenclasses → @class_object (Class/Module) instance methods.
        # This ensures inherited `def self.foo` methods shadow `Class#foo` instance methods.
        if is_a?(ClassObject)
          if @eigenclass
            m = @eigenclass.lookup_method(name)
            # If eigenclass has UNDEF_SENTINEL, stop searching entirely (undef_method in singleton class)
            return nil if m.nil? && @eigenclass.get_method(name) == ModuleObject::UNDEF_SENTINEL
            return m if m
          end
          c = superclass
          while c
            m = c.eigenclass_method(name)
            return nil if m == ModuleObject::UNDEF_SENTINEL
            return m unless m.nil?
            c = c.is_a?(ClassObject) ? c.superclass : nil
          end
          return @class_object&.lookup_method(name)
        end
        # For modules and regular objects: own eigenclass first, then class object
        lookup_class.lookup_method(name)
      end

      # Shared dispatch: look up and invoke a method on self by Symbol name.
      # Falls back to method_missing if the method is not found.
      # private_ok: true when called with implicit receiver (no explicit receiver in source)
      # implicit_self: true for bare-word calls (no receiver) — raises NameError vs NoMethodError on miss
      def dispatch(context, name, args, kw_args, block = nil, private_ok: false, implicit_self: false, public_only: false)
        method = lookup_instance_method(name)
        unless method.nil?
          case method.visibility
          when :private
            unless private_ok
              raise FrozoneException.make(:NoMethodError, "private method '#{name}' called for an instance of #{@class_object.name}")
            end
          when :protected
            if public_only
              raise FrozoneException.make(:NoMethodError, "protected method '#{name}' called for an instance of #{@class_object.name}")
            end
            caller_class = context&.frame&.the_self&.class_object
            unless subclass_of?(caller_class, @class_object)
              raise FrozoneException.make(:NoMethodError, "protected method '#{name}' called for an instance of #{@class_object.name}")
            end
          end
          return method.invoke(context, self, args, kw_args, block)
        end

        mm = lookup_instance_method(:method_missing)
        if mm.nil?
          raise "BUG: method_missing not defined on #{@class_object.name} (looking up: #{name.inspect})"
        end
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
        @instance_variables_hash.key?(name)
      end

      def get_ivar(name)
        @instance_variables_hash.fetch(name, NilObject::NIL)
      end

      def set_ivar(name, value)
        if @frozen_object
          type_name = is_a?(ModuleObject) ? (is_a?(ClassObject) ? "Class" : "Module") : (@class_object&.name&.to_s || "Object")
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{type_name}: #{inspect_for_error}", receiver: self)
        end
        if is_a?(StringObject) && chilled?
          ctx = Fiber[:context]
          Frozone::Vm.emit_warning(ctx, chilled_warning) if ctx
          unchilled!
        end
        @instance_variables_hash[name] = value
      end

      def is_singleton_class = false

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
