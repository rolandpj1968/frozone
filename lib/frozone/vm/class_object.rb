require_relative 'module_object'
require_relative 'object_object'
require_relative 'string_object'

module Frozone
  module Vm
    class ClassObject < ModuleObject
      attr_accessor :superclass
      attr_accessor :is_singleton_class, :singleton_of
      attr_accessor :uninitialized_class

      def initialize(name, namespace, superclass)
        super(name, namespace, defined?(Core::CLASS_CLASS) ? Core::CLASS_CLASS : nil)
        @superclass = superclass
        @subclasses = []
        # Register this class as a direct subclass of superclass (after bootstrap)
        superclass.register_subclass(self) if superclass.is_a?(ClassObject)
      end

      def register_subclass(klass)
        @subclasses ||= []
        @subclasses << klass unless @subclasses.include?(klass)
      end

      def direct_subclasses
        (@subclasses ||= []).reject { |sc| sc.is_singleton_class }
      end

      def to_s = "class(#{@name})"

      # Called after CLASS_CLASS is defined to wire up the class pointer on bootstrap ClassObjects
      def patch_class_object
        @class_object = Core::CLASS_CLASS
      end

      # Create a singleton-class copy of original_sc, owned by new_owner.
      # Used by dup/clone implementations to copy singleton-class state.
      def self.clone_singleton(original_sc, new_owner)
        sc = new(nil, nil, original_sc.superclass)
        sc.is_singleton_class = true
        sc.singleton_of = new_owner
        sc.methods_table.replace(original_sc.methods_table.dup)
        sc.constants_table.replace(original_sc.constants_table.dup)
        original_sc.modules.reverse_each { |mod| sc.add_module(mod) }
        sc
      end

      def new_instance(context, args, kwargs, block = nil)
        o = allocate_instance
        o.dispatch(context, :initialize, args, kwargs, block, private_ok: true)
        o
      end

      def allocate_instance
        if ancestors_list.any? { |a| a.equal?(Core::ARRAY_CLASS) }
          ArrayObject.new([], self)
        elsif ancestors_list.any? { |a| a.equal?(Core::STRING_CLASS) }
          StringObject.new("".b, class_obj: self)
        elsif ancestors_list.any? { |a| a.equal?(Core::HASH_CLASS) }
          h = HashObject.new({})
          h.class_object = self
          h
        else
          ObjectObject.new(self)
        end
      end

      def ancestors_include?(mod)
        return true if equal?(mod)
        @prepends&.any? { |m| m.ancestors_include?(mod) } ||
          @modules&.any? { |m| m.ancestors_include?(mod) } ||
          (@superclass&.ancestors_include?(mod) || false)
      end

      def ancestors_list
        result = []
        @prepends&.each { |mod| result.concat(mod.ancestors_list) }
        result << self
        @modules&.each { |mod| result.concat(mod.ancestors_list) }
        result.concat(@superclass.ancestors_list) unless @superclass.nil?
        result
      end

      def lookup_method_after(name, origin)
        ancs = ancestors_list
        idx = ancs.index { |a| a.equal?(origin) }
        return nil if idx.nil?
        ancs[(idx + 1)..].each do |ancestor|
          m = ancestor.get_method(name)
          return nil if m == ModuleObject::UNDEF_SENTINEL
          return m unless m.nil?
        end
        nil
      end

      def lookup_method_owner_after(name, origin)
        ancs = ancestors_list
        idx = ancs.index { |a| a.equal?(origin) }
        return nil if idx.nil?
        ancs[(idx + 1)..].each do |ancestor|
          m = ancestor.get_method(name)
          return nil if m == ModuleObject::UNDEF_SENTINEL
          if m
            return m.is_a?(Method) && m.original_owner ? m.original_owner : ancestor
          end
        end
        nil
      end

      # TODO - private/public
      def lookup_method(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        # 1. Prepended modules
        @prepends&.each do |mod|
          method = mod.lookup_method(name)
          return nil if method == ModuleObject::UNDEF_SENTINEL
          return method unless method.nil?
        end

        # 2. This class's methods
        method = get_method(name)
        return nil if method == ModuleObject::UNDEF_SENTINEL
        return method unless method.nil?

        # 3. Module methods (recursive — searches included modules of included modules)
        @modules&.each do |mod|
          method = mod.lookup_method(name)
          return nil if method == ModuleObject::UNDEF_SENTINEL
          return method unless method.nil?
        end

        # 4. Superclass
        @superclass&.lookup_method(name)
      end

      def lookup_method_owner(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @prepends&.each do |mod|
          owner = mod.lookup_method_owner(name)
          return owner if owner
        end
        m = get_method(name)
        return self if m && m != ModuleObject::UNDEF_SENTINEL

        @modules&.each do |mod|
          owner = mod.lookup_method_owner(name)
          return owner if owner
        end
        @superclass&.lookup_method_owner(name)
      end

      # Class-hierarchy look-up
      # Note that full constant lookup starts with the lexical scopes in ModuleObject.lookup_constant.
      def lookup_constant(name)
        lookup_constant_with_owner(name).first
      end

      def lookup_constant_with_owner(name, stop_at_object: false, skip_own: false)
        # 1. Prepended modules
        unless @prepends.nil? || skip_own
          @prepends.each do |mod|
            val = mod.get_constant(name)
            return [val, mod] unless val.nil?
          end
        end

        # 2. This class's constants (skipped for Object when stop_at_object is active)
        unless skip_own
          val = get_constant(name)
          return [val, self] unless val.nil?
        end

        # 3. Module constants (including transitive included modules)
        unless @modules.nil?
          @modules.each do |mod|
            val, owner = mod.lookup_constant_with_owner(name)
            return [val, owner] unless val.nil?
          end
        end

        # 4. Superclass (full chain); for explicit A::B path lookup, skip Object's own constants
        unless @superclass.nil?
          skip_obj_own = stop_at_object && @superclass.equal?(Core::OBJECT_CLASS)
          val, owner = @superclass.lookup_constant_with_owner(name, stop_at_object: stop_at_object, skip_own: skip_obj_own)
          return [val, owner] unless val.nil?
        end

        [nil, nil]
      end
    end
  end
end
