require_relative 'node'
require_relative 'constant_write'
require_relative '../vm/module_object'
require_relative '../vm/frozone_exception'
require_relative '../vm/globals'

module Frozone
  module Ast
    # FOO ||= val — assigns only if FOO is undefined or falsy
    class ConstantOrWrite < Node
      attr_reader :name
      attr_reader :value_node
      def initialize(name, value_node)
        @name = name
        @value_node = value_node
      end

      def children = [@value_node]

      def evaluate(context)
        current = Vm::ModuleObject.lookup_constant(@name, context.frame.scopes)
        if !current.nil? && current.truthy?
          return current
        end
        val = @value_node.evaluate(context)
        scope = context.scopes.last
        scope.set_constant(@name, val)
        ConstantWrite.maybe_set_name(val, @name, scope)
        Vm.trigger_const_added(context, scope, @name)
        val
      end
    end

    # FOO &&= val — assigns only if FOO is defined and truthy
    class ConstantAndWrite < Node
      def initialize(name, value_node)
        @name = name
        @value_node = value_node
      end

      def children = [@value_node]

      def evaluate(context)
        current = Vm::ModuleObject.lookup_constant(@name, context.frame.scopes)
        raise Vm::FrozoneException.make(:NameError, "uninitialized constant #{@name}") if current.nil?
        return current unless current.truthy?
        val = @value_node.evaluate(context)
        context.scopes.last.set_constant(@name, val)
        val
      end
    end

    # Module::FOO ||= val — evaluates Module once, assigns only if FOO undefined or falsy
    class ConstantPathOrWrite < Node
      def initialize(parent_node, name, value_node)
        @parent_node = parent_node
        @name = name
        @value_node = value_node
      end

      def children = [@parent_node, @value_node]

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        raise Vm::FrozoneException.make(:TypeError, "#{@parent_node}::#{@name}: parent is not a module") unless parent.is_a?(Vm::ModuleObject)
        current = parent.get_constant(@name)
        if !current.nil? && current.truthy?
          return current
        end
        val = @value_node.evaluate(context)
        parent.set_constant(@name, val)
        ConstantWrite.maybe_set_name(val, @name, parent)
        Vm.trigger_const_added(context, parent, @name)
        val
      end
    end

    # Module::FOO &&= val — evaluates Module once, assigns only if FOO defined and truthy
    class ConstantPathAndWrite < Node
      def initialize(parent_node, name, value_node)
        @parent_node = parent_node
        @name = name
        @value_node = value_node
      end

      def children = [@parent_node, @value_node]

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        raise Vm::FrozoneException.make(:TypeError, "#{@parent_node}::#{@name}: parent is not a module") unless parent.is_a?(Vm::ModuleObject)
        current = parent.get_constant(@name)
        raise Vm::FrozoneException.make(:NameError, "uninitialized constant #{@parent_node}::#{@name}") if current.nil?
        return current unless current.truthy?
        val = @value_node.evaluate(context)
        Vm::emit_warning(context, "already initialized constant #{parent.name}::#{@name}")
        parent.set_constant(@name, val)
        val
      end
    end
  end
end
