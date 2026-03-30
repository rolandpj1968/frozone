require_relative 'node'

module Frozone
  module Ast
    # a[*args] += val — evaluates receiver and index args once, returns new value (not []= result)
    class IndexOperatorWrite < Node
      def initialize(operator, receiver_node, index_arg_nodes, value_node)
        @operator        = operator
        @receiver_node   = receiver_node
        @index_arg_nodes = index_arg_nodes
        @value_node      = value_node
      end

      def children = [@receiver_node, *@index_arg_nodes, @value_node].compact

      def evaluate(context)
        implicit = @receiver_node.nil?
        receiver = implicit ? context.frame.the_self : @receiver_node.evaluate(context)
        index_args = @index_arg_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        current = receiver.dispatch(context, :[], index_args, {}, nil, private_ok: implicit)
        val     = @value_node.evaluate(context)
        result  = current.dispatch(context, @operator, [val], {})
        receiver.dispatch(context, :[]=, index_args + [result], {}, nil, private_ok: implicit)
        result
      end
    end

    # a[*args] ||= val — evaluates receiver and index args once, returns new value
    class IndexOrWrite < Node
      def initialize(receiver_node, index_arg_nodes, value_node)
        @receiver_node   = receiver_node
        @index_arg_nodes = index_arg_nodes
        @value_node      = value_node
      end

      def children = [@receiver_node, *@index_arg_nodes, @value_node].compact

      def evaluate(context)
        implicit = @receiver_node.nil?
        receiver   = implicit ? context.frame.the_self : @receiver_node.evaluate(context)
        index_args = @index_arg_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        current = receiver.dispatch(context, :[], index_args, {}, nil, private_ok: implicit)
        return current if current.truthy?
        val = @value_node.evaluate(context)
        receiver.dispatch(context, :[]=, index_args + [val], {}, nil, private_ok: implicit)
        val
      end
    end

    # a[*args] &&= val — evaluates receiver and index args once, returns new value
    class IndexAndWrite < Node
      def initialize(receiver_node, index_arg_nodes, value_node)
        @receiver_node   = receiver_node
        @index_arg_nodes = index_arg_nodes
        @value_node      = value_node
      end

      def children = [@receiver_node, *@index_arg_nodes, @value_node].compact

      def evaluate(context)
        implicit = @receiver_node.nil?
        receiver   = implicit ? context.frame.the_self : @receiver_node.evaluate(context)
        index_args = @index_arg_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        current = receiver.dispatch(context, :[], index_args, {}, nil, private_ok: implicit)
        return current unless current.truthy?
        val = @value_node.evaluate(context)
        receiver.dispatch(context, :[]=, index_args + [val], {}, nil, private_ok: implicit)
        val
      end
    end
  end
end
