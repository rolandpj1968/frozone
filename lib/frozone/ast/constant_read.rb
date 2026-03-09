require_relative 'node'
require_relative '../vm/module_object'

module Frozone
  module Ast
    class ConstantRead < Node
      def initialize(name)
        @name = check_type("name", name, Symbol)
      end

      def to_s = "con(#{@name})"

      def evaluate(context) = Vm::ModuleObject.lookup_constant(@name, context.scopes)
    end
  end
end
