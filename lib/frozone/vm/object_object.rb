module Frozone
  module Vm
    class ObjectObject
      @@bootstrapping = true

      def self.end_bootstrap! = @@bootstrapping = false

      attr_reader :class_object, :eigenclass
      attr_accessor :class_object

      attr_reader :frozen_object
      attr_reader :instance_variables_hash

      def frozen_object? = @frozen_object
      def eigenclass = @eigenclass
      def lookup_class = @eigenclass || @class_object
      # Returns a method from the eigenclass (including its included modules).
      def eigenclass_method(name) = @eigenclass&.lookup_method(name)
      def inspect = "#<#{self.class.name}>"
      def ivar_defined?(name) = @instance_variables_hash.key?(name)
      def get_ivar(name) = @instance_variables_hash.fetch(name, NilObject::NIL)
      def is_singleton_class = false
      def inspect_for_error = "#<#{@class_object&.name}>"
      def truthy? = !equal?(FalseObject::FALSE) && !equal?(NilObject::NIL)
      def define_singleton_method(name, unbound_method) = singleton_class.set_method(name, unbound_method)

      def initialize(class_object)
        unless @@bootstrapping || class_object.is_a?(ClassObject)
          raise "ObjectObject class_object must be a ClassObject"
        end
        @class_object = class_object
        @instance_variables_hash = {}
        @eigenclass = nil
        @frozen_object = false
      end

      # Internal: overwrite the eigenclass pointer. Used by clone/dup machinery
      # to install a pre-cloned singleton class on a freshly-built copy.
      def __set_eigenclass__(ec) = @eigenclass = ec

      def freeze_object!
        @frozen_object = true
        # Also freeze the singleton class if it exists
        @eigenclass&.freeze_object!
        self
      end

      # Internal — used by Object#dup and Object#clone(freeze: false) in
      # core/4.0/object.rb via Intrinsics.object_unfreeze. MRI has no
      # public unfreeze; this is the only path to clear the flag.
      def unfreeze_object! = (@frozen_object = false; self)

      # Copy base ObjectObject fields from source into self (used by dup/clone).
      # Sets eigenclass and frozen state directly — this is intentionally internal.
      def copy_fields_from(source, eigenclass: nil, frozen: false)
        @class_object = source.class_object
        @instance_variables_hash = source.instance_variables_hash.dup
        @eigenclass = eigenclass
        @frozen_object = frozen
        self
      end

      def singleton_class
        unless @eigenclass
          # For ClassObjects, singleton class inherits from the superclass's singleton class
          sc_superclass =
            if is_a?(ClassObject) && superclass
              superclass.singleton_class
            else
              @class_object
            end
          @eigenclass = ClassObject.new(nil, nil, sc_superclass).tap do |sc|
            sc.is_singleton_class = true
            sc.singleton_of = self
            # Propagate frozen state to newly-created singleton class
            sc.freeze_object! if @frozen_object
          end
        end
        @eigenclass
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

      # Look up a method with active refinements using the correct interleaved priority order:
      # 1. Singleton class (eigenclass) methods always win over refinements
      # 2. For each ancestor in MRO order: refinement for that ancestor, then ancestor's own method
      # This implements Ruby's actual refinement lookup: refinements override a class's OWN methods,
      # but NOT methods defined in subclasses (which appear earlier in the MRO).
      def lookup_method_with_refinements(name, active_refinements)
        # Eigenclass (singleton class) methods take priority over ALL refinements.
        # Mirrors the ClassObject logic in lookup_instance_method.
        if is_a?(ClassObject)
          if @eigenclass
            m = @eigenclass.lookup_method(name)
            return nil if m.nil? && @eigenclass.get_method(name) == ModuleObject::UNDEF_SENTINEL
            return m if m
          end
          c = superclass
          while c
            ec_m = c.eigenclass_method(name)
            return nil if ec_m == ModuleObject::UNDEF_SENTINEL
            return ec_m unless ec_m.nil?
            c = c.is_a?(ClassObject) ? c.superclass : nil
          end
          # Fall through to instance method lookup via @class_object
          return @class_object&.lookup_method(name)
        end

        # For non-ClassObjects: check eigenclass first (singleton class takes priority over refinements)
        if @eigenclass
          m = @eigenclass.lookup_method(name)
          return m if m
        end

        # Walk the ancestor chain, interleaving refinements with own methods.
        # ancestors_list includes all prepends, the class, and all includes in MRO order.
        @class_object.ancestors_list.each do |ancestor|
          # Refinement for this ancestor takes priority over ancestor's own methods
          ref_mod = active_refinements[ancestor.object_id]
          if ref_mod
            m = ref_mod.get_method(name)
            return m if m && m != ModuleObject::UNDEF_SENTINEL
          end
          # Ancestor's own method (directly defined on this ancestor, not inherited)
          m = ancestor.get_method(name)
          return nil if m == ModuleObject::UNDEF_SENTINEL  # explicit undef stops search
          return m if m
        end
        nil
      end

      # Shared dispatch: look up and invoke a method on self by Symbol name.
      # Falls back to method_missing if the method is not found.
      # private_ok: true when called with implicit receiver (no explicit receiver in source)
      # implicit_self: true for bare-word calls (no receiver) — raises NameError vs NoMethodError on miss
      def dispatch(context, name, args, kw_args, block = nil, private_ok: false, implicit_self: false, public_only: false)
        # When active refinements are present, use the interleaved lookup that correctly
        # prioritizes: singleton class > (refinement for each ancestor, then ancestor's own methods).
        # Otherwise, use the standard lookup.
        active_refinements = context&.frame&.active_refinements
        method =
          if active_refinements && !active_refinements.empty?
            lookup_method_with_refinements(name, active_refinements)
          else
            lookup_instance_method(name)
          end

        prev_violation = Fiber[:mm_visibility_violation]
        unless method.nil? || method == ModuleObject::UNDEF_SENTINEL
          visibility_ok = case method.visibility
                          when :private
                            private_ok
                          when :protected
                            !public_only && subclass_of?(context&.frame&.the_self&.class_object, @class_object)
                          else
                            true
                          end
          if visibility_ok
            return method.invoke(context, self, args, kw_args, block, callee_name: name)
          end
          # Visibility check failed — store violation info for method_missing / default error message
          Fiber[:mm_visibility_violation] = [method.visibility, name, @class_object.name]
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
          Fiber[:mm_visibility_violation] = prev_violation
        end
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
