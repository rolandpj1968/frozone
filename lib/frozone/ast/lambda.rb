require_relative 'node'
require_relative '../vm/block_object'
require_relative '../vm/proc_object'

module Frozone
  module Ast
    class Lambda < Node
      def initialize(params, locals, body)
        @params = check_array_type("params", params, Symbol)
        @locals = check_array_type("locals", locals, Symbol)
        @body = check_type("body", body, Node)
      end

      def evaluate(context)
        block = Vm::BlockObject.new(@params, @locals, @body, context.frame)
        Vm::ProcObject.new(block, lambda: true)
      end
    end
  end
end
