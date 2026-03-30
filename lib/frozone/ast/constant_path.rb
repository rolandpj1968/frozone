require_relative 'node'
require_relative 'constant_write'
require_relative '../vm/frozone_exception'
require_relative '../vm/globals'

module Frozone
  module Ast
    # Evaluates to the root Object class (for ::Foo absolute constant paths)
    class RootNamespaceNode < Node
      INSTANCE = new

      def evaluate(_context) = Vm::Core::OBJECT_CLASS
    end

    class ConstantPath < Node
      def initialize(parent_node, name)
        @parent_node = parent_node
        @name = name
      end

      def children = [@parent_node]
      def to_s = "#{@parent_node}::#{@name}"

      def defined_check?(context)
        # Avoid const_missing when checking parent — use defined_check? if available.
        if @parent_node.is_a?(ConstantPath) || @parent_node.is_a?(ConstantRead)
          return false unless @parent_node.defined_check?(context)
        end
        parent = @parent_node.evaluate(context)
        return false unless parent.is_a?(Vm::ModuleObject)

        stop = @parent_node.is_a?(Ast::RootNamespaceNode) ? false : parent.is_a?(Vm::ClassObject)
        c, = parent.lookup_constant_with_owner(@name, stop_at_object: stop)
        return true if !c.nil? && !parent.constant_private?(@name)
        # Autoloaded constants also count as defined, unless file is already in $LOADED_FEATURES
        autoload_path = parent.lookup_autoload(@name, inherit: true)
        return false unless autoload_path
        loaded = Vm::GLOBALS[:"$LOADED_FEATURES"]
        path_rb = autoload_path.end_with?('.rb') ? autoload_path : "#{autoload_path}.rb"
        full = File.exist?(path_rb) ? File.expand_path(path_rb) : path_rb
        return false if loaded.raw.any? { |s| s.raw == full }
        true
      rescue Vm::FrozoneException
        false
      end

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        raise Vm::FrozoneException.make(:TypeError, "#{@parent_node}::#{@name}: parent is not a module") unless parent.is_a?(Vm::ModuleObject)
        stop = @parent_node.is_a?(Ast::RootNamespaceNode) ? false : parent.is_a?(Vm::ClassObject)
        c, owner = parent.lookup_constant_with_owner(@name, stop_at_object: stop)
        if c.nil?
          # Check for autoload before const_missing
          autoload_path = parent.lookup_autoload(@name, inherit: true)
          if autoload_path
            Vm::Intrinsics.autoload_dispatch_require(context, autoload_path)
            # File loaded: if constant still not defined, remove autoload and fall through to const_missing
            c, owner = parent.lookup_constant_with_owner(@name, stop_at_object: stop)
            parent.remove_autoload(@name) if c.nil?
          end
          # Dispatch const_missing — default raises NameError with proper name/inspect message
          return parent.dispatch(context, :const_missing, [Vm::SymbolObject.from(@name)], {}, nil, private_ok: true) if c.nil?
        end
        # Check privacy in the defining module — dispatch const_missing (gives user-defined
        # const_missing a chance to handle it); the default raises NameError.
        if owner&.constant_private?(@name)
          owner_name = owner.is_a?(Vm::ModuleObject) ? owner.name : nil
          label = owner_name ? "#{owner_name}::#{@name}" : @name.to_s
          begin
            return parent.dispatch(context, :const_missing, [Vm::SymbolObject.from(@name)], {}, nil, private_ok: true)
          rescue Vm::FrozoneException => e
            # Re-raise with the more specific private constant message if const_missing just raised NameError
            vm_obj = e.vm_object
            if vm_obj.is_a?(Vm::ObjectObject)
              klass = vm_obj.class_object
              is_name_error = false
              while klass
                is_name_error = true if klass.name == :NameError
                klass = klass.superclass
              end
              if is_name_error
                raise Vm::FrozoneException.make(:NameError, "private constant #{label} referenced", name: @name, receiver: owner)
              end
            end
            raise
          end
        end
        Vm::Intrinsics.maybe_warn_deprecated_constant(context, owner, @name)
        c
      end
    end

    class ConstantPathWrite < Node
      def initialize(parent_node, name, value_node, source_location: nil)
        @parent_node = parent_node
        @name = name
        @value_node = value_node
        @source_location = source_location
      end

      def children = [@parent_node, @value_node]

      def evaluate(context)
        parent = @parent_node.evaluate(context)
        value = @value_node.evaluate(context)
        raise Vm::FrozoneException.make(:TypeError, "#{@parent_node}::#{@name}: parent is not a module") unless parent.is_a?(Vm::ModuleObject)
        Vm::emit_warning(context, "already initialized constant #{parent.name}::#{@name}") if parent.get_constant(@name)
        parent.set_constant(@name, value, source_location: @source_location)
        ConstantWrite.maybe_set_name(value, @name, parent)
        Vm.trigger_const_added(context, parent, @name)
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

      def children = [@parent_node, @value_node]

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
