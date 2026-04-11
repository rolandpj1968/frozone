# Module erasure pass — flatten ancestor methods and constants into
# each concrete class's own tables.
#
# Runs after the load phase (all classes/modules settled) and before
# TI, so that TI sees flat per-class method/ivar tables.
#
# Does NOT remove module objects from the constant table — they're
# still needed for is_a? / ancestors queries. Only the method/constant
# tables are flattened.

module Frozone
  module Compiler
    module ModuleErasure
      CORE_PATH_MARKERS = %w[lib/core/4.0/ lib/frozone/vm/ lib/frozone/ast/].freeze

      # Flatten all user classes reachable from the given scope.
      # Mutates the live ClassObject method/constant tables in place.
      def self.flatten!(scope)
        visited = Set.new
        flatten_scope!(scope, visited)
      end

      private

      def self.user_class?(cls)
        cls.methods_table&.any? { |_, m| m.is_a?(Vm::Method) && user_loc?(m.source_location) } ||
          cls.constants_locations&.any? { |_, loc| user_loc?(loc) }
      end

      def self.user_loc?(loc)
        return false if loc.nil?
        file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
        CORE_PATH_MARKERS.none? { |m| file.include?(m) }
      end

      def self.flatten_scope!(scope, visited)
        scope.constants_table&.each do |_name, value|
          next unless value.is_a?(Vm::ClassObject)
          next if visited.include?(value.object_id)
          visited << value.object_id
          flatten_scope!(value, visited)
          flatten_class!(value) if user_class?(value)
        end
        scope.constants_table&.each do |_name, value|
          next unless value.is_a?(Vm::ModuleObject) && !value.is_a?(Vm::ClassObject)
          next if visited.include?(value.object_id)
          visited << value.object_id
          flatten_scope!(value, visited)
        end
      end

      def self.flatten_class!(cls)
        # Walk the ancestor chain in MRO order and collect methods/constants
        # that the class doesn't already define itself.
        ancestors = build_mro(cls)

        # Flatten methods: walk MRO, first definition wins (already in
        # the class's own table takes precedence).
        ancestors.each do |ancestor|
          next if ancestor.equal?(cls)  # skip self
          ancestor.methods_table&.each do |mname, method|
            next if cls.methods_table.key?(mname)  # own method takes priority
            next if method == Vm::ModuleObject::UNDEF_SENTINEL
            cls.methods_table[mname] = method
          end
        end

        # Flatten constants: same precedence rule.
        # Skip ModuleObject values (class/module references) — those create
        # circular constant tables. Only flatten value constants (integers,
        # strings, etc.) that Ruby resolves through the ancestor chain.
        ancestors.each do |ancestor|
          next if ancestor.equal?(cls)
          ancestor.constants_table&.each do |cname, value|
            next if cls.constants_table.key?(cname)
            next if value.is_a?(Vm::ModuleObject)  # don't copy class refs
            cls.set_constant(cname, value)
            loc = ancestor.get_constant_location(cname)
            cls.constants_locations[cname] = loc if loc
          end
        end
      end

      # Build the method resolution order for a class, matching Ruby's
      # C3 linearisation: prepends → class → includes → superclass chain.
      # Returns an array of ModuleObjects in lookup order.
      def self.build_mro(cls)
        result = []
        seen = Set.new
        add_to_mro(cls, result, seen)
        # Walk superclass chain
        sc = cls.superclass
        while sc
          add_to_mro(sc, result, seen)
          sc = sc.is_a?(Vm::ClassObject) ? sc.superclass : nil
        end
        result
      end

      def self.add_to_mro(mod, result, seen)
        return if seen.include?(mod.object_id)
        # Prepends first
        mod.prepends.each { |m| add_to_mro(m, result, seen) }
        # The module/class itself
        seen << mod.object_id
        result << mod
        # Includes after
        mod.modules.each { |m| add_to_mro(m, result, seen) }
      end
    end
  end
end
