require_relative 'node'
require_relative '../vm/globals'

module Frozone
  module Ast
    class GlobalVariableRead < Node
      def initialize(name)
        @name = check_type("name", name, Symbol)
      end

      def to_s = "gvar(#{@name})"

      def evaluate(context)
        case @name
        when :"$@"
          bang = Vm::GLOBALS.fetch(:"$!", Vm::NilObject::NIL)
          bang.is_a?(Vm::NilObject) ? Vm::NilObject::NIL : Vm::GLOBALS.fetch(:"$@", Vm::NilObject::NIL)
        when :"$-0"
          Vm::GLOBALS.fetch(:"$/", Vm::NilObject::NIL)
        when :"$-d"
          Vm::GLOBALS.fetch(:"$DEBUG", Vm::FalseObject::FALSE)
        when :"$-v", :"$-w"
          Vm::GLOBALS.fetch(:"$VERBOSE", Vm::FalseObject::FALSE)
        else
          Vm::GLOBALS.fetch(@name, Vm::NilObject::NIL)
        end
      end
    end
  end
end
