require_relative 'node'
require_relative '../vm/module_object'
require_relative '../vm/frozone_exception'

module Frozone
  module Ast
    class ConstantRead < Node
      def initialize(name)
        @name = check_type("name", name, Symbol)
      end

      def to_s = "con(#{@name})"

      def evaluate(context)
        val = Vm::ModuleObject.lookup_constant(@name, context.frame.scopes)
        raise Vm::FrozoneException.make(:NameError, "uninitialized constant #{@name}") if val.nil?
        val
      end
    end
  end
end
