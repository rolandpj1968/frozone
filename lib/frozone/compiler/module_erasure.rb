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
      #
      # codegen: true  → rename prepend originals + record super targets (for Crystal)
      #          false → just flatten methods (interpreter super uses live MRO)
      def self.flatten!(scope, codegen: false)
        visited = Set.new
        flatten_scope!(scope, visited, codegen: codegen)
      end

      private

      def self.user_class?(cls)
        # A class should be flattened if any module in its include/prepend
        # chain (transitively) has user content. Don't walk the SUPERCLASS
        # chain — that would pull in all core classes.
        check_mod_tree = ->(mod, visited = Set.new) {
          return false if visited.include?(mod.object_id)
          visited << mod.object_id
          return true if mod.methods_table&.any? { |_, m| m.is_a?(Vm::Method) && user_loc?(m.source_location) }
          return true if mod.constants_locations&.any? { |_, loc| user_loc?(loc) }
          mod.modules.any? { |m| check_mod_tree.call(m, visited) } ||
            mod.prepends.any? { |m| check_mod_tree.call(m, visited) }
        }
        check_mod_tree.call(cls)
      end

      def self.user_loc?(loc)
        return false if loc.nil?
        file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
        CORE_PATH_MARKERS.none? { |m| file.include?(m) }
      end

      def self.flatten_scope!(scope, visited, codegen: false)
        scope.constants_table&.each do |_name, value|
          next unless value.is_a?(Vm::ClassObject)
          next if visited.include?(value.object_id)
          visited << value.object_id
          flatten_scope!(value, visited, codegen: codegen)
          flatten_class!(value, codegen: codegen) if user_class?(value)
        end
        scope.constants_table&.each do |_name, value|
          next unless value.is_a?(Vm::ModuleObject) && !value.is_a?(Vm::ClassObject)
          next if visited.include?(value.object_id)
          visited << value.object_id
          flatten_scope!(value, visited, codegen: codegen)
        end
      end

      def self.flatten_class!(cls, codegen: false)
        ancestors = build_mro(cls)

        # Flatten methods using MRO order. For each method name, the
        # FIRST definition in the MRO wins. When a prepended method
        # overrides the class's own method, rename the original so
        # `super` in the prepend can reach it.
        #
        # Walk MRO to build a flat method table. Track super targets
        # for prepended methods that override later definitions.
        mro_methods = {}  # {name => [method, source_module]} in MRO order
        ancestors.each do |ancestor|
          ancestor.methods_table&.each do |mname, method|
            next if method == Vm::ModuleObject::UNDEF_SENTINEL
            mro_methods[mname] ||= []
            mro_methods[mname] << [method, ancestor]
          end
        end

        # For each method name: the first definition in MRO order wins.
        #
        # In codegen mode, prepended methods that override the class's own
        # method need special handling: Crystal has no MRO-based super, so
        # we rename the original and rewrite super → call to the renamed
        # method. The super target chain maps each method's object_id to
        # the renamed method name that its `super` should dispatch to.
        #
        # In interpreter mode, we just flatten (first wins) — the
        # interpreter's super already walks the live MRO correctly, so
        # no rename or rewriting is needed.
        super_targets = {}
        mro_methods.each do |mname, chain|
          winner_method, winner_source = chain.first
          if !winner_source.equal?(cls) && cls.methods_table.key?(mname)
            if codegen
              # Codegen: rename overridden methods so super can reach them.
              # Crystal has no MRO-based super — each link in the prepend
              # chain calls the renamed next method directly.
              chain.each_cons(2) do |(m, _src), (next_m, _next_src)|
                renamed = :"__prepend_super_#{mname}_#{super_targets.size}"
                super_targets[m.object_id] = renamed
                cls.methods_table[renamed] = next_m
              end
              cls.methods_table[mname] = winner_method
            end
            # Interpreter: DON'T override the class's own method — the
            # interpreter's lookup_method already walks prepends first
            # and finds the prepended method naturally. Overwriting would
            # break super (the original method would be lost).
          else
            # Non-conflicting method: safe to flatten in both modes.
            cls.methods_table[mname] = winner_method
          end
        end

        cls.prepend_super_targets = super_targets unless super_targets.empty?

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
