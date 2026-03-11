require_relative 'node'
require_relative '../vm/frozone_exception'

module Frozone
  module Ast
    class Yield < Node
      def initialize(arg_nodes)
        @arg_nodes = check_array_type("arg_nodes", arg_nodes, Node)
      end

      def evaluate(context)
        block = context.frame.block
        raise Vm::FrozoneException.make(:LocalJumpError, "no block given (yield)") if block.nil?
        args = @arg_nodes.flat_map do |n|
          n.is_a?(SplatArg) ? n.evaluate(context).raw : [n.evaluate(context)]
        end
        block.invoke(context, args)
      end
    end
  end
end
