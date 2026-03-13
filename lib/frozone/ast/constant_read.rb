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
        !Vm::ModuleObject.lookup_constant(@name, context.frame.scopes).nil?
      end

      def evaluate(context)
        val = Vm::ModuleObject.lookup_constant(@name, context.frame.scopes)
        return val unless val.nil?

        # Call const_missing on innermost lexical scope (or Object if none)
        scope = context.frame.scopes.last || Vm::Core::OBJECT_CLASS
        begin
          scope.dispatch(context, :const_missing, [Vm::SymbolObject.from(@name)], {})
        rescue RuntimeError
          # const_missing not available — raise default NameError
          raise Vm::FrozoneException.make(:NameError, "uninitialized constant #{@name}")
        end
      end
    end
  end
end
