require_relative 'node'
require_relative '../vm/frozone_exception'

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

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        raise Vm::FrozoneException.make(:TypeError, "#{@parent_node}::#{@name}: parent is not a module") unless parent.is_a?(Vm::ModuleObject)
        c = parent.lookup_constant(@name)
        raise Vm::FrozoneException.make(:NameError, "uninitialized constant #{@parent_node}::#{@name}") if c.nil?
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
        raise Vm::FrozoneException.make(:TypeError, "#{@parent_node}::#{@name}: parent is not a module") unless parent.is_a?(Vm::ModuleObject)
        value = @value_node.evaluate(context)
        parent.set_constant(@name, value)
        value
      end
    end
  end
end
