require_relative 'node'

module Frozone
  module Ast
    # a[*args] += val — evaluates receiver and index args once, returns new value (not []= result)
    class IndexOperatorWrite < Node
      def initialize(operator, receiver_node, index_arg_nodes, value_node)
        @operator       = check_type("operator", operator, Symbol)
        @receiver_node  = check_type("receiver_node", receiver_node, Node)
        @index_arg_nodes = check_array_type("index_arg_nodes", index_arg_nodes, Node)
        @value_node     = check_type("value_node", value_node, Node)
      end

      def evaluate(context)
        receiver  = @receiver_node.evaluate(context)
        index_args = @index_arg_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        current = receiver.dispatch(context, :[], index_args, {})
        val     = @value_node.evaluate(context)
        result  = current.dispatch(context, @operator, [val], {})
        receiver.dispatch(context, :[]=, index_args + [result], {})
        result
      end
    end

    # a[*args] ||= val — evaluates receiver and index args once, returns new value
    class IndexOrWrite < Node
      def initialize(receiver_node, index_arg_nodes, value_node)
        @receiver_node   = check_type("receiver_node", receiver_node, Node)
        @index_arg_nodes = check_array_type("index_arg_nodes", index_arg_nodes, Node)
        @value_node      = check_type("value_node", value_node, Node)
      end

      def evaluate(context)
        receiver   = @receiver_node.evaluate(context)
        index_args = @index_arg_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        current = receiver.dispatch(context, :[], index_args, {})
        return current if current.truthy?
        val = @value_node.evaluate(context)
        receiver.dispatch(context, :[]=, index_args + [val], {})
        val
      end
    end

    # a[*args] &&= val — evaluates receiver and index args once, returns new value
    class IndexAndWrite < Node
      def initialize(receiver_node, index_arg_nodes, value_node)
        @receiver_node   = check_type("receiver_node", receiver_node, Node)
        @index_arg_nodes = check_array_type("index_arg_nodes", index_arg_nodes, Node)
        @value_node      = check_type("value_node", value_node, Node)
      end

      def evaluate(context)
        receiver   = @receiver_node.evaluate(context)
        index_args = @index_arg_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        current = receiver.dispatch(context, :[], index_args, {})
        return current unless current.truthy?
        val = @value_node.evaluate(context)
        receiver.dispatch(context, :[]=, index_args + [val], {})
        val
      end
    end
  end
end
