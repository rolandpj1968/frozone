require_relative 'node'
require_relative '../vm/frozone_exception'

module Frozone
  module Ast
    class Yield < Node
      def initialize(arg_nodes, kw_arg_nodes = {})
        @arg_nodes    = check_array_type("arg_nodes", arg_nodes, Node)
        @kw_arg_nodes = kw_arg_nodes  # Hash<Symbol, Node>
      end

      def evaluate(context)
        block = context.frame.block
        raise Vm::FrozoneException.make(:LocalJumpError, "no block given (yield)") if block.nil?
        args = @arg_nodes.flat_map do |n|
          n.is_a?(SplatArg) ? n.evaluate(context).raw : [n.evaluate(context)]
        end
        kw_args = @kw_arg_nodes.transform_values { |v| v.evaluate(context) }
        block.invoke(context, args, kw_args: kw_args)
      end
    end
  end
end
