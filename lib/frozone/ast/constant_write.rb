require_relative 'node'
require_relative '../vm/module_object'
require_relative '../vm/globals'

module Frozone
  module Ast
    class ConstantWrite < Node
      def initialize(name, value_node, source_location: nil)
        @name = name
        @value_node = value_node
        @source_location = source_location
      end

      def children = [@value_node]
      def to_s = "con=(#{@name}, #{@value_node})"

      def evaluate(context) = store(context, @value_node.evaluate(context))

      def store(context, value, source_location: @source_location)
        scope = context.frame.scopes.last
        if scope.get_constant(@name)
          scope_name = scope.is_a?(Vm::ModuleObject) ? (scope.name || scope.to_s) : nil
          const_full = scope_name ? "#{scope_name}::#{@name}" : @name.to_s
          Vm::emit_warning(context, "already initialized constant #{const_full}")
        end
        scope.set_constant(@name, value, source_location: source_location)
        # Auto-name anonymous classes/modules when first assigned to a constant
        ConstantWrite.maybe_set_name(value, @name, scope)
        prev_call_site = context.call_site
        context.call_site = "#{source_location[0]}:#{source_location[1]}" if source_location
        Vm.trigger_const_added(context, scope, @name)
        context.call_site = prev_call_site
        value
      end

      # Assign a name to value if it's an anonymous/non-permanent module being stored in scope.
      # Propagates permanence to nested constants when container becomes permanent.
      def self.maybe_set_name(value, const_name, scope)
        return unless value.is_a?(Vm::ModuleObject)
        return if value.name_permanent

        has_temp_name = value.instance_variable_defined?(:@temporary_name) &&
                        !value.instance_variable_get(:@temporary_name).nil?
        container_permanent = scope.equal?(Vm::Core::OBJECT_CLASS) || scope.name_permanent

        if container_permanent
          # Permanently name the module and propagate to its constants
          value.set_name(const_name)
          value.namespace = scope.equal?(Vm::Core::OBJECT_CLASS) ? nil : scope
          value.instance_variable_set(:@temporary_name, nil) if value.instance_variable_defined?(:@temporary_name)
          value.instance_variable_set(:@cached_name_str, nil)
          value.mark_name_permanent!
          # Propagate permanence to nested constants
          propagate_permanent_name(value)
        elsif value.name.nil? && !has_temp_name
          # Only give an anonymous module a namespace-based name if it has no name at all
          value.set_name(const_name)
          value.namespace = scope.equal?(Vm::Core::OBJECT_CLASS) ? nil : scope
        end
        # If has_temp_name && !container_permanent: keep temp name, don't overwrite
      end

      def self.propagate_permanent_name(mod)
        mod.constants_table.each do |name, nested|
          next unless nested.is_a?(Vm::ModuleObject)
          next if nested.name_permanent

          nested.set_name(name)
          nested.namespace = mod
          nested.instance_variable_set(:@temporary_name, nil) if nested.instance_variable_defined?(:@temporary_name)
          nested.instance_variable_set(:@cached_name_str, nil)
          nested.mark_name_permanent!
          propagate_permanent_name(nested)
        end
      end
    end
  end
end
