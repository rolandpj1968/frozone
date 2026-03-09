require_relative 'node'
require_relative '../vm/globals'

module Frozone
  module Ast
    class GlobalVariableRead < Node
      def initialize(name)
        @name = check_type("name", name, Symbol)
      end

      def to_s = "gvar(#{@name})"

      def evaluate(context) = Vm::GLOBALS.fetch(@name, Vm::NilObject::NIL)
    end
  end
end
