require_relative 'node'
require_relative '../vm/module_object'
require_relative '../vm/globals'

module Frozone
  module Ast
    class ConstantWrite < Node
      def initialize(name, value_node)
        @name = name
        @value_node = value_node
      end

      def to_s = "con=(#{@name}, #{@value_node})"

      def evaluate(context) = store(context, @value_node.evaluate(context))

      def store(context, value)
        scope = context.frame.scopes.last
        Vm::emit_warning(context, "already initialized constant #{@name}") if scope.get_constant(@name)
        scope.set_constant(@name, value)
        # Auto-name anonymous classes/modules when first assigned to a constant
        if value.is_a?(Vm::ModuleObject) && value.name.nil?
          value.set_name(@name)
          value.instance_variable_set(:@namespace, scope) unless scope.equal?(Vm::Core::OBJECT_CLASS)
        end
        value
      end
    end
  end
end
