require_relative 'node'

module Frozone
  module Ast
    class ConstantPath < Node
      def initialize(parent_node, name)
        @parent_node = check_type("parent_node", parent_node, Node)
        @name = check_type("name", name, Symbol)
      end

      def to_s = "#{@parent_node}::#{@name}"

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        raise "#{@parent_node}::#{@name}: parent is not a module" unless parent.is_a?(Vm::ModuleObject)
        c = parent.get_constant(@name)
        raise "uninitialized constant #{@parent_node}::#{@name}" if c.nil?
        c
      end
    end

    class ConstantPathWrite < Node
      def initialize(parent_node, name, value_node)
        @parent_node = check_type("parent_node", parent_node, Node)
        @name = check_type("name", name, Symbol)
        @value_node = check_type("value_node", value_node, Node)
      end

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        raise "#{@parent_node}::#{@name}: parent is not a module" unless parent.is_a?(Vm::ModuleObject)
        value = @value_node.evaluate(context)
        parent.set_constant(@name, value)
        value
      end
    end
  end
end
