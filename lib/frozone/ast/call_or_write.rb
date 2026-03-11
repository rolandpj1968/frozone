require_relative 'node'

module Frozone
  module Ast
    # a.b ||= val — evaluates receiver once, returns new value (not setter result)
    class CallOrWrite < Node
      def initialize(read_name, write_name, receiver_node, value_node)
        @read_name = check_type("read_name", read_name, Symbol)
        @write_name = check_type("write_name", write_name, Symbol)
        @receiver_node = check_nil_or_type("receiver_node", receiver_node, Node)
        @value_node = check_type("value_node", value_node, Node)
      end

      def evaluate(context)
        implicit = @receiver_node.nil?
        receiver = implicit ? context.frame.the_self : @receiver_node.evaluate(context)
        current = receiver.dispatch(context, @read_name, [], {}, nil, private_ok: implicit)
        return current if current.truthy?
        val = @value_node.evaluate(context)
        receiver.dispatch(context, @write_name, [val], {}, nil, private_ok: implicit)
        val
      end
    end

    # a.b &&= val — evaluates receiver once, returns new value (not setter result)
    class CallAndWrite < Node
      def initialize(read_name, write_name, receiver_node, value_node)
        @read_name = check_type("read_name", read_name, Symbol)
        @write_name = check_type("write_name", write_name, Symbol)
        @receiver_node = check_nil_or_type("receiver_node", receiver_node, Node)
        @value_node = check_type("value_node", value_node, Node)
      end

      def evaluate(context)
        implicit = @receiver_node.nil?
        receiver = implicit ? context.frame.the_self : @receiver_node.evaluate(context)
        current = receiver.dispatch(context, @read_name, [], {}, nil, private_ok: implicit)
        return current unless current.truthy?
        val = @value_node.evaluate(context)
        receiver.dispatch(context, @write_name, [val], {}, nil, private_ok: implicit)
        val
      end
    end

    # a.b += val — evaluates receiver once, returns new value (not setter result)
    class CallOperatorWrite < Node
      def initialize(read_name, write_name, operator, receiver_node, value_node)
        @read_name = check_type("read_name", read_name, Symbol)
        @write_name = check_type("write_name", write_name, Symbol)
        @operator = check_type("operator", operator, Symbol)
        @receiver_node = check_nil_or_type("receiver_node", receiver_node, Node)
        @value_node = check_type("value_node", value_node, Node)
      end

      def evaluate(context)
        implicit = @receiver_node.nil?
        receiver = implicit ? context.frame.the_self : @receiver_node.evaluate(context)
        current = receiver.dispatch(context, @read_name, [], {}, nil, private_ok: implicit)
        val = @value_node.evaluate(context)
        result = current.dispatch(context, @operator, [val], {})
        receiver.dispatch(context, @write_name, [result], {}, nil, private_ok: implicit)
        result
      end
    end
  end
end
