require_relative 'node'
require_relative '../vm/module_object'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class ConstantRead < Node
      def initialize(name)
        @name = check_type("name", name, Vm::SymbolObject)
      end

      def to_s = "con(#{@name.raw})"

      def evaluate(context) = Vm::ModuleObject.lookup_constant(@name, context.scopes)
    end
  end
end
