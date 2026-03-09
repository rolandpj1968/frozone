require_relative 'node'

module Frozone
  module Ast
    class Yield < Node
      def initialize(arg_nodes)
        @arg_nodes = check_array_type("arg_nodes", arg_nodes, Node)
      end

      def evaluate(context)
        block = context.frame.block
        # TODO: raise LocalJumpError (a proper VM exception) instead
        raise "LocalJumpError: no block given (yield)" if block.nil?
        args = @arg_nodes.map { |n| n.evaluate(context) }
        block.invoke(context, args)
      end
    end
  end
end
