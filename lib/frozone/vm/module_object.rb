require_relative 'core'
require_relative 'method'
require_relative 'object_object'

module Frozone
  module Vm
    class ModuleObject < ObjectObject
      # TODO - the Module class _can_ be subclassed in ruby - need to work out how to deal with that
      attr_reader :name, :class_variables
      attr_accessor :namespace
      attr_reader :methods_table, :constants_table, :constants_locations
      attr_accessor :current_visibility
      def private_constants_table = @private_constants
      def is_singleton_class = false
      def singleton_of       = nil
      def prepends = @prepends || []
      def modules  = @modules  || []
      def to_s = "module #{@name}"

      def initialize(name, namespace, class_object = Core::MODULE_CLASS)
        super(class_object)

        raise "class/module name must be a Symbol or nil" unless name.nil? || name.is_a?(Symbol)
        @name = name
        raise "class/module namespace must be a module" unless namespace.nil? or namespace.is_a?(ModuleObject)
        @namespace = namespace
        @methods_table = {}
        @constants_table = {}
        @constants_locations = {}
        @autoloads = {}
        @class_variables = {}
        @current_visibility = :public
      end

      def set_name(name)
        raise "class/module name must be a Symbol" unless name.is_a?(Symbol)
        @name = name
      end

      def name_permanent = @name_permanent

      def mark_name_permanent! = @name_permanent = true

      def clear_name!
        @name = nil
        @name_permanent = false
        @cached_name_str = nil
      end

      def full_name
        parts = []
        current = self
        seen = {}
        while current && !current.equal?(Core::OBJECT_CLASS)
          break if seen.key?(current.object_id)
          seen[current.object_id] = true
          if current.name
            parts.unshift(current.name.to_s)
          else
            # Anonymous parent: use inspect-style representation as prefix
            type = current.is_a?(ClassObject) ? "Class" : "Module"
            parts.unshift("#<#{type}:0x#{current.object_id.to_s(16)}>")
          end
          current = current.namespace
        end
        parts.empty? ? @name : parts.join("::").to_sym
      end

      def ancestors_include?(mod)
        return true if equal?(mod)
        @prepends&.any? { |m| m.ancestors_include?(mod) } ||
          @modules&.any? { |m| m.ancestors_include?(mod) }
      end

      def prepend_module(mod)
        @prepends ||= []
        # Only skip if already in our own direct prepend chain (not superclass or included modules)
        return if @prepends.any? { |m| m.ancestors_include?(mod) }
        @prepends.unshift(mod)
      end

      def add_module(mod)
        @modules ||= []
        return if ancestors_include?(mod)
        @modules.unshift(mod)
      end

      def ancestors_list = (@prepends&.flat_map(&:ancestors_list) || []) + [self] + (@modules&.flat_map(&:ancestors_list) || [])

      def lookup_method(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @prepends&.each do |mod|
          m = mod.lookup_method(name)
          return nil if m == UNDEF_SENTINEL
          return m unless m.nil?
        end
        m = get_method(name)
        return nil if m == UNDEF_SENTINEL
        return m unless m.nil?

        @modules&.each do |mod|
          m = mod.lookup_method(name)
          return nil if m == UNDEF_SENTINEL
          return m unless m.nil?
        end
        nil
      end

      def lookup_method_owner(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @prepends&.each do |mod|
          owner = mod.lookup_method_owner(name)
          return owner if owner
        end
        m = get_method(name)
        return m.original_owner if m.is_a?(VisibilityOverride)
        return self if m && m != UNDEF_SENTINEL

        @modules&.each do |mod|
          owner = mod.lookup_method_owner(name)
          return owner if owner
        end
        nil
      end

      # Sentinel for undef_method - stops method lookup
      UNDEF_SENTINEL = :__undef__

      # Visibility override for inherited methods: tracks new visibility without copying method body.
      # When invoked, dynamically looks up the current implementation from the original owner.
      class VisibilityOverride
        attr_accessor :visibility
        attr_reader :original_owner, :method_name
        def original_owner = @original_owner
        def dup_with_visibility(new_vis, **_kwargs) = VisibilityOverride.new(new_vis, @original_owner, @method_name)
        def alias_as(_new_name) = VisibilityOverride.new(@visibility, @original_owner, @method_name)

        def initialize(vis, original_owner, method_name)
          @visibility = vis
          @original_owner = original_owner
          @method_name = method_name
        end

        def invoke(context, receiver, args, kw_args, block, from_super: false, callee_name: nil)
          m = @original_owner.lookup_method(@method_name)
          raise "BUG: VisibilityOverride: method #{@method_name} not found in #{@original_owner}" unless m && m != UNDEF_SENTINEL
          m.invoke(context, receiver, args, kw_args, block, from_super: from_super, callee_name: callee_name)
        end

        def uses_block
          m = @original_owner.lookup_method(@method_name)
          m&.uses_block || false
        end

        def source_location
          m = @original_owner.lookup_method(@method_name)
          m&.source_location
        end
      end

      def set_method(name, method)
        raise "method must be a Method, DefinedMethod, or VisibilityOverride" unless method.is_a?(Method) || method.is_a?(DefinedMethod) || method.is_a?(VisibilityOverride)
        if frozen_object?
          if is_a?(ClassObject) && is_singleton_class
            so = singleton_of
            if so.is_a?(IntegerObject) || so.is_a?(FloatObject) || so.is_a?(SymbolObject) ||
               so.is_a?(NilObject) || so.is_a?(TrueObject) || so.is_a?(FalseObject)
              raise FrozoneException.make(:TypeError, "can't define singleton", receiver: self)
            end
          end
          type_name = is_a?(ClassObject) ? "Class" : "Module"
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{type_name}: #{inspect_for_frozen}", receiver: self)
        end
        # TODO thread safety
        @methods_table[name] = method
      end

      def inspect_for_frozen
        n = name
        n ? n.to_s : inspect_for_error
      end

      def inspect_for_error
        n = name
        n ? "#<#{is_a?(ClassObject) ? 'Class' : 'Module'}: #{n}>" : "#<#{is_a?(ClassObject) ? 'Class' : 'Module'}:0x#{object_id.to_s(16)}>"
      end

      def undef_method(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)
        @methods_table[name] = UNDEF_SENTINEL
      end

      def remove_method(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)
        @methods_table.delete(name)
      end

      def get_method(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        v = @methods_table[name]
        # If the method is the undef sentinel, return a special marker
        # (callers must check for UNDEF_SENTINEL to stop lookup)
        v == UNDEF_SENTINEL ? UNDEF_SENTINEL : v
      end

      def get_class_var(name)
        # Walk superclass chain, detecting "overtaken" case:
        # if the variable appears in both a subclass and an ancestor, raise RuntimeError.
        found_in = nil
        found_value = nil
        c = self
        while c
          if c.class_variables.key?(name)
            if found_in.nil?
              found_in = c
              found_value = c.class_variables[name]
            else
              raise FrozoneException.make(:RuntimeError,
                                          "class variable #{name} of #{found_in.name || '#<Class>'} is overtaken by #{c.name || '#<Class>'}")
            end
          end
          c = c.is_a?(ClassObject) ? c.superclass : nil
        end
        found_value
      end

      def set_class_var(name, value)
        # write to the class that owns it, or this class if new
        c = self
        while c
          if c.class_variables.key?(name)
            c.class_variables[name] = value
            return value
          end
          c = c.is_a?(ClassObject) ? c.superclass : nil
        end
        self.class_variables[name] = value
        value
      end

      def set_constant(name, value, source_location: nil)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @constants_table[name] = value
        if source_location
          @constants_locations[name] = source_location
        else
          @constants_locations.delete(name)
        end
        @@constant_generation += 1
      end

      def get_constant(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @constants_table[name]
      end

      def get_constant_location(name) = @constants_locations[name]

      # Total number of autoloads pending across the entire program.
      # Constant lookup hot paths short-circuit when this is 0 — see
      # lookup_autoload_for_const_with_scope and lookup_autoload.
      # Profiling TILE_LUT-style integer-arithmetic loops showed ~25%
      # of runtime in autoload walks for code that registered zero
      # autoloads anywhere.
      @@autoload_count = 0
      def self.autoload_count = @@autoload_count
      def self.any_autoloads? = @@autoload_count > 0

      # Monotonic constant generation counter. Bumped on every
      # set_constant / constant deletion. ConstantRead AST nodes
      # cache their resolved value plus the generation at which they
      # cached, and re-resolve only when the global generation has
      # advanced. The cache covers the common case of repeated
      # `is_a?(Integer)` / `is_a?(Float)` style lookups in hot loops
      # where the resolved constant never actually changes.
      @@constant_generation = 0
      def self.constant_generation = @@constant_generation
      def self.bump_constant_generation = @@constant_generation += 1

      def set_autoload(name, path, source_location: nil)
        @@autoload_count += 1 unless @autoloads.key?(name)
        @autoloads[name] = path
        @autoload_locations ||= {}
        if source_location
          @autoload_locations[name] = source_location
        else
          @autoload_locations.delete(name)
        end
      end

      def get_autoload(name)
        return nil unless @@autoload_count > 0
        # Only return if constant not yet defined
        @autoloads[name] unless @constants_table.key?(name)
      end

      def get_autoload_location(name) = @autoload_locations&.[](name)

      def remove_autoload(name)
        @@autoload_count -= 1 if @autoloads.key?(name)
        @autoloads.delete(name)
        @autoload_locations&.delete(name)
      end

      def lookup_autoload(name, inherit: true)
        return nil unless @@autoload_count > 0
        path = get_autoload(name)
        return path if path
        return nil unless inherit
        prepends.each do |m|
          path = m.lookup_autoload(name, inherit: true)
          return path if path
        end
        modules.each do |m|
          path = m.lookup_autoload(name, inherit: true)
          return path if path
        end
        if is_a?(ClassObject) && superclass
          path = superclass.lookup_autoload(name, inherit: true)
          return path if path
        end
        nil
      end

      def mark_constant_private(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @private_constants ||= {}
        @private_constants[name] = true
      end

      def constant_private?(name) = (@private_constants&.key?(name) || false)

      # Lookup constant in this module and its included/prepended modules.
      # Returns [value, owner_module] where owner_module is the module that defines the constant.
      # Returns [nil, nil] if not found.
      def lookup_constant_with_owner(name, stop_at_object: false)
        @prepends&.each do |mod|
          val, owner = mod.lookup_constant_with_owner(name)
          return [val, owner] unless val.nil?
        end
        val = get_constant(name)
        return [val, self] unless val.nil?
        @modules&.each do |mod|
          val, owner = mod.lookup_constant_with_owner(name)
          return [val, owner] unless val.nil?
        end
        [nil, nil]
      end

      # Lookup constant in this module and its included modules.
      def lookup_constant(name) = lookup_constant_with_owner(name).first
      def self.lookup_autoload_for_const(name, scopes) = lookup_autoload_for_const_with_scope(name, scopes).first

      # Returns [path, declaring_scope] for the autoload registered for +name+ in the given scopes.
      # declaring_scope is the module/class that directly has the autoload (nil if found only via inherit).
      def self.lookup_autoload_for_const_with_scope(name, scopes)
        return [nil, nil] unless @@autoload_count > 0
        lex_scopes = (!scopes.empty? && scopes[0].equal?(Core::OBJECT_CLASS)) ? scopes[1..] : scopes
        lex_scopes.reverse_each do |class_or_module|
          path = class_or_module.get_autoload(name)
          return [path, class_or_module] if path
        end
        lex_scopes.reverse_each do |class_or_module|
          path = class_or_module.lookup_autoload(name, inherit: true)
          return [path, nil] if path
        end
        if defined?(Core::OBJECT_CLASS) && Core::OBJECT_CLASS
          path = Core::OBJECT_CLASS.lookup_autoload(name, inherit: true)
          return [path, nil] if path
        end
        [nil, nil]
      end

      def self.lookup_constant(name, scopes)
        # 1. Lexical scopes (only direct constants, not inheritance).
        # Skip the outermost OBJECT_CLASS if it is the base/ambient scope (index 0).
        # It is NOT part of the explicit lexical nesting unless `class Object` was
        # explicitly opened (in which case OBJECT_CLASS appears again at index > 0).
        # Object is always searched as a last resort in step 3.
        lex_scopes = (!scopes.empty? && scopes[0].equal?(Core::OBJECT_CLASS)) ? scopes[1..] : scopes
        lex_scopes.reverse_each do |class_or_module|
          constant = class_or_module.get_constant(name)
          return constant unless constant.nil?
          # For singleton classes, also search the attached class (singleton_of) directly.
          # In MRI, constant lookup inside `class << SomeModule` can see SomeModule's constants.
          if class_or_module.is_a?(ClassObject) && class_or_module.is_singleton_class && class_or_module.singleton_of.is_a?(ModuleObject)
            constant = class_or_module.singleton_of.get_constant(name)
            return constant unless constant.nil?
          end
        end

        # 2. Class/module hierarchy look-up for each lexical scope (innermost first).
        # Walk each scope's ancestor chain (superclass + included modules).
        # Use same filtered scopes to avoid double-searching ambient OBJECT_CLASS.
        lex_scopes.reverse_each do |class_or_module|
          # For singleton classes, search the attached class's hierarchy (not singleton's hierarchy).
          search_scope = if class_or_module.is_a?(ClassObject) && class_or_module.is_singleton_class && class_or_module.singleton_of.is_a?(ModuleObject)
            class_or_module.singleton_of
          else
            class_or_module
          end
          constant = search_scope.lookup_constant(name)
          return constant unless constant.nil?
        end

        # 3. Search Object as a last resort (constants included into Object are globally visible)
        # Skip only if the innermost non-ambient lexical scope is a Class (not Module) that
        # is a subclass of BasicObject but NOT of Object (i.e., directly extends BasicObject).
        if defined?(Core::OBJECT_CLASS) && Core::OBJECT_CLASS
          skip_object = begin
            innermost = lex_scopes.last
            # Skip Object only for explicitly-defined BasicObject subclasses.
            # Singleton classes are transparent — their constant lookup scope is inherited
            # from the definition site, not the singleton class hierarchy.
            innermost.is_a?(ClassObject) &&
              !innermost.equal?(Core::OBJECT_CLASS) &&
              !innermost.is_singleton_class &&
              !innermost.ancestors_list.any? { |a| a.equal?(Core::OBJECT_CLASS) }
          rescue StandardError
            false
          end
          unless skip_object
            constant = Core::OBJECT_CLASS.lookup_constant(name)
            return constant unless constant.nil?
          end
        end

        # 4. No luck - const_missing will be dispatched by caller
        nil
      end
    end
  end
end
