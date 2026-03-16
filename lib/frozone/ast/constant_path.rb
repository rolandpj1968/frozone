require_relative 'node'
require_relative '../vm/frozone_exception'
require_relative '../vm/globals'

module Frozone
  module Ast
    # Evaluates to the root Object class (for ::Foo absolute constant paths)
    class RootNamespaceNode < Node
      INSTANCE = new

      def evaluate(_context)
        Vm::Core::OBJECT_CLASS
      end
    end

    class ConstantPath < Node
      def initialize(parent_node, name)
        @parent_node = parent_node
        @name = name
      end

      def to_s = "#{@parent_node}::#{@name}"

      def defined_check?(context)
        # Avoid const_missing when checking parent — use defined_check? if available.
        if @parent_node.respond_to?(:defined_check?)
          return false unless @parent_node.defined_check?(context)
        end
        parent = @parent_node.evaluate(context)
        return false unless parent.is_a?(Vm::ModuleObject)

        stop = @parent_node.is_a?(Ast::RootNamespaceNode) ? false : parent.is_a?(Vm::ClassObject)
        c, = parent.lookup_constant_with_owner(@name, stop_at_object: stop)
        !c.nil? && !parent.constant_private?(@name)
      rescue Vm::FrozoneException
        false
      end

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        raise Vm::FrozoneException.make(:TypeError, "#{@parent_node}::#{@name}: parent is not a module") unless parent.is_a?(Vm::ModuleObject)
        stop = @parent_node.is_a?(Ast::RootNamespaceNode) ? false : parent.is_a?(Vm::ClassObject)
        c, owner = parent.lookup_constant_with_owner(@name, stop_at_object: stop)
        if c.nil?
          # Dispatch const_missing — default raises NameError with proper name/inspect message
          return parent.dispatch(context, :const_missing, [Vm::SymbolObject.from(@name)], {})
        end
        # Check privacy in the defining module — dispatch const_missing on the owner
        # (not parent/child) so that e.receiver reflects the class holding the private constant
        if owner&.constant_private?(@name)
          return owner.dispatch(context, :const_missing, [Vm::SymbolObject.from(@name)], {})
        end
        c
      end
    end

    class ConstantPathWrite < Node
      def initialize(parent_node, name, value_node)
        @parent_node = parent_node
        @name = name
        @value_node = value_node
      end

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        value = @value_node.evaluate(context)
        raise Vm::FrozoneException.make(:TypeError, "#{@parent_node}::#{@name}: parent is not a module") unless parent.is_a?(Vm::ModuleObject)
        Vm::emit_warning(context, "already initialized constant #{parent.name}::#{@name}") if parent.get_constant(@name)
        parent.set_constant(@name, value)
        # Auto-name anonymous classes/modules when first assigned to a constant
        if value.is_a?(Vm::ModuleObject) && value.name.nil?
          value.set_name(@name)
          value.namespace = parent unless parent.equal?(Vm::Core::OBJECT_CLASS)
        end
        value
      end
    end
    # A::B += val — evaluates parent module expression exactly once.
    class ConstantPathOperatorWrite < Node
      def initialize(parent_node, name, operator, value_node)
        @parent_node = parent_node
        @name = name
        @operator = operator
        @value_node = value_node
      end

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        raise Vm::FrozoneException.make(:TypeError, "#{@parent_node}::#{@name}: parent is not a module") unless parent.is_a?(Vm::ModuleObject)
        current = parent.lookup_constant(@name)
        raise Vm::FrozoneException.make(:NameError, "uninitialized constant #{@name}") if current.nil?
        val = @value_node.evaluate(context)
        result = current.dispatch(context, @operator, [val], {})
        Vm::emit_warning(context, "already initialized constant #{parent.name}::#{@name}")
        parent.set_constant(@name, result)
        result
      end
    end
  end
end
