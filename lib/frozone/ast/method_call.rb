require_relative 'node'

module Frozone
  module Ast
    class MethodCall < Node
      def initialize(name, receiver_node, arg_nodes, kw_arg_nodes)
        @name = check_type("name", name, Symbol)
        @receiver_node = check_nil_or_type("receiver_node", receiver_node, Node)
        @arg_nodes = check_array_type("arg_nodes", arg_nodes, Node)
        @kw_arg_nodes = check_hash_of_types("kw_arg_nodes", kw_arg_nodes, Node, Node)
      end

      def to_s
        "call(#{@name}, #{@receiver_node || '_'}, #{@arg_nodes.map(&:to_s).join(', ')})"
      end

      def evaluate(context)
        receiver =
          if @receiver_node.nil?
            context.frame.the_self
          else
            @receiver_node.evaluate(context)
          end

        args = @arg_nodes.map { |p| p.evaluate(context) }
        kw_args = @kw_arg_nodes.to_h { |kw_node, value_node| [kw_node.evaluate(context), value_node.evaluate(context)] }

        receiver.dispatch(context, @name, args, kw_args)
      end
    end
  end
end
