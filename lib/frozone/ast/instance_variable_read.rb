require_relative 'node'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class InstanceVariableRead < Node
      def initialize(name)
        @name = check_type("name", name, Vm::SymbolObject)
      end

      def to_s = "ivar(#{@name.raw})"

      def evaluate(context) = context.frame.the_self.get_ivar(@name)
    end
  end
end
