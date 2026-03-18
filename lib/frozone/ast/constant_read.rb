require_relative 'node'
require_relative '../vm/module_object'
require_relative '../vm/frozone_exception'

module Frozone
  module Ast
    class ConstantRead < Node
      def initialize(name)
        @name = name
      end

      def to_s = "con(#{@name})"

      def defined_check?(context)
        return true unless Vm::ModuleObject.lookup_constant(@name, context.frame.scopes).nil?
        autoload_path = Vm::ModuleObject.lookup_autoload_for_const(@name, context.frame.scopes)
        return false unless autoload_path
        # Autoload pending, but not if file is already in $LOADED_FEATURES
        loaded = Vm::GLOBALS[:"$LOADED_FEATURES"]
        path_rb = autoload_path.end_with?('.rb') ? autoload_path : "#{autoload_path}.rb"
        full = File.exist?(path_rb) ? File.expand_path(path_rb) : path_rb
        return false if loaded.raw.any? { |s| s.raw == full }
        true
      end

      def evaluate(context)
        val = Vm::ModuleObject.lookup_constant(@name, context.frame.scopes)
        return val unless val.nil?

        # Check for autoloads in lexical scope chain before const_missing
        scope = context.frame.scopes.last || Vm::Core::OBJECT_CLASS
        autoload_path, autoload_scope = Vm::ModuleObject.lookup_autoload_for_const_with_scope(@name, context.frame.scopes)
        if autoload_path
          Vm::Intrinsics.kernel_require(context, nil, Vm::StringObject.new(autoload_path))
          # If the declaring scope didn't get the constant, warn once in verbose mode
          if autoload_scope && autoload_scope.get_constant(@name).nil?
            if Vm::GLOBALS.fetch(:"$VERBOSE", Vm::FalseObject::FALSE).truthy?
              scope_name = autoload_scope.full_name
              Vm.emit_warning(context, "Expected #{autoload_path} to define #{scope_name}::#{@name} but it didn't")
            end
            autoload_scope.remove_autoload(@name)
          end
          val = Vm::ModuleObject.lookup_constant(@name, context.frame.scopes)
          # File loaded but constant not defined anywhere: fall through to const_missing
          return val unless val.nil?
        end

        # Call const_missing on innermost lexical scope (or Object if none)
        begin
          scope.dispatch(context, :const_missing, [Vm::SymbolObject.from(@name)], {}, nil, private_ok: true)
        rescue RuntimeError
          # const_missing not available — raise default NameError
          raise Vm::FrozoneException.make(:NameError, "uninitialized constant #{@name}")
        end
      end
    end
  end
end
