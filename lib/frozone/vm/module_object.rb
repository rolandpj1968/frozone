require_relative 'core'
require_relative 'method'
require_relative 'object_object'

module Frozone
  module Vm
    class ModuleObject < ObjectObject
      # TODO - the Module class _can_ be subclassed in ruby - need to work out how to deal with that
      attr_reader :name, :class_variables
      attr_accessor :namespace
      attr_reader :methods_table, :constants_table
      def private_constants_table = @private_constants

      def set_name(name)
        raise "class/module name must be a Symbol" unless name.is_a?(Symbol)
        @name = name
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
      attr_accessor :current_visibility
      def is_singleton_class = false
      def singleton_of       = nil

      def initialize(name, namespace, class_object = Core::MODULE_CLASS)
        super(class_object)

        raise "class/module name must be a Symbol or nil" unless name.nil? || name.is_a?(Symbol)
        @name = name
        raise "class/module namespace must be a module" unless namespace.nil? or namespace.is_a?(ModuleObject)
        @namespace = namespace
        @methods_table = {}
        @constants_table = {}
        @class_variables = {}
        @current_visibility = :public
      end

      def to_s = "module #{@name}"

      def prepends = @prepends || []
      def modules  = @modules  || []

      def ancestors_include?(mod)
        return true if equal?(mod)
        @prepends&.any? { |m| m.ancestors_include?(mod) } ||
          @modules&.any? { |m| m.ancestors_include?(mod) }
      end

      def prepend_module(mod)
        @prepends ||= []
        return if ancestors_include?(mod)
        @prepends << mod
      end

      def add_module(mod)
        @modules ||= []
        return if ancestors_include?(mod)
        @modules.unshift(mod)
      end

      def ancestors_list
        result = []
        @prepends&.each { |mod| result.concat(mod.ancestors_list) }
        result << self
        @modules&.each { |mod| result.concat(mod.ancestors_list) }
        result
      end

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
        return self if get_method(name) && get_method(name) != UNDEF_SENTINEL

        @modules&.each do |mod|
          owner = mod.lookup_method_owner(name)
          return owner if owner
        end
        nil
      end

      # Sentinel for undef_method - stops method lookup
      UNDEF_SENTINEL = :__undef__

      def set_method(name, method)
        raise "method must be a Method or DefinedMethod" unless method.is_a?(Method) || method.is_a?(DefinedMethod)
        if frozen_object?
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

      def set_constant(name, value)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @constants_table[name] = value
      end

      def get_constant(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @constants_table[name]
      end

      def mark_constant_private(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @private_constants ||= {}
        @private_constants[name] = true
      end

      def constant_private?(name)
        @private_constants&.key?(name) || false
      end

      # Lookup constant in this module and its included modules.
      # Returns [value, owner_module] where owner_module is the module that defines the constant.
      # Returns [nil, nil] if not found.
      def lookup_constant_with_owner(name, stop_at_object: false)
        val = get_constant(name)
        return [val, self] unless val.nil?
        @modules&.each do |mod|
          val, owner = mod.lookup_constant_with_owner(name)
          return [val, owner] unless val.nil?
        end
        [nil, nil]
      end

      # Lookup constant in this module and its included modules.
      def lookup_constant(name)
        lookup_constant_with_owner(name).first
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
        end

        # 2. Class/module hierarchy look-up for each lexical scope (innermost first).
        # Walk each scope's ancestor chain (superclass + included modules).
        # Use same filtered scopes to avoid double-searching ambient OBJECT_CLASS.
        lex_scopes.reverse_each do |class_or_module|
          constant = class_or_module.lookup_constant(name)
          return constant unless constant.nil?
        end

        # 3. Search Object as a last resort (constants included into Object are globally visible)
        if defined?(Core::OBJECT_CLASS) && Core::OBJECT_CLASS
          constant = Core::OBJECT_CLASS.lookup_constant(name)
          return constant unless constant.nil?
        end

        # 4. No luck - const_missing will be dispatched by caller
        nil
      end
    end
  end
end
