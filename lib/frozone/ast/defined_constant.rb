require_relative 'node'

module Frozone
  module Ast
    # defined?(ConstantName) — returns "constant" if the constant is defined, nil otherwise
    class DefinedConstant < Node
      def initialize(name)
        @name = check_type("name", name, Symbol)
      end

      def evaluate(context)
        val = Vm::ModuleObject.lookup_constant(@name, context.frame.scopes)
        val.nil? ? Vm::NilObject::NIL : Vm::StringObject.new("constant")
      end
    end
  end
end
