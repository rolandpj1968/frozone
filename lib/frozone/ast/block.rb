require_relative 'node'
require_relative '../vm/block_object'

module Frozone
  module Ast
    class Block < Node
      def initialize(params, locals, body)
        @params = check_array_type("params", params, Symbol)
        @locals = check_array_type("locals", locals, Symbol)
        @body = check_type("body", body, Node)
      end

      def evaluate(context)
        Vm::BlockObject.new(@params, @locals, @body, context.frame)
      end
    end
  end
end
