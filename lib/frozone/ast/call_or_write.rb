require_relative 'node'

module Frozone
  module Ast
    # a.b ||= val — evaluates receiver once, returns new value (not setter result)
    class CallOrWrite < Node
      attr_reader :read_name, :write_name, :receiver_node, :value_node, :safe_nav
      def initialize(read_name, write_name, receiver_node, value_node, safe_nav: false)
        @read_name = read_name
        @write_name = write_name
        @receiver_node = receiver_node
        @value_node = value_node
        @safe_nav = safe_nav
      end

      def children = [@receiver_node, @value_node].compact

      def evaluate(context)
        implicit = @receiver_node.nil?
        receiver = implicit ? context.frame.the_self : @receiver_node.evaluate(context)
        return Vm::NilObject::NIL if @safe_nav && receiver.is_a?(Vm::NilObject)
        current = receiver.dispatch(context, @read_name, [], {}, nil, private_ok: implicit)
        return current if current.truthy?
        val = @value_node.evaluate(context)
        receiver.dispatch(context, @write_name, [val], {}, nil, private_ok: implicit)
        val
      end
    end

    # a.b &&= val — evaluates receiver once, returns new value (not setter result)
    class CallAndWrite < Node
      attr_reader :read_name, :write_name, :receiver_node, :value_node, :safe_nav
      def initialize(read_name, write_name, receiver_node, value_node, safe_nav: false)
        @read_name = read_name
        @write_name = write_name
        @receiver_node = receiver_node
        @value_node = value_node
        @safe_nav = safe_nav
      end

      def children = [@receiver_node, @value_node].compact

      def evaluate(context)
        implicit = @receiver_node.nil?
        receiver = implicit ? context.frame.the_self : @receiver_node.evaluate(context)
        return Vm::NilObject::NIL if @safe_nav && receiver.is_a?(Vm::NilObject)
        current = receiver.dispatch(context, @read_name, [], {}, nil, private_ok: implicit)
        return current unless current.truthy?
        val = @value_node.evaluate(context)
        receiver.dispatch(context, @write_name, [val], {}, nil, private_ok: implicit)
        val
      end
    end

    # a.b += val — evaluates receiver once, returns new value (not setter result)
    class CallOperatorWrite < Node
      attr_reader :read_name, :write_name, :operator, :receiver_node, :value_node, :safe_nav
      def initialize(read_name, write_name, operator, receiver_node, value_node, safe_nav: false)
        @read_name = read_name
        @write_name = write_name
        @operator = operator
        @receiver_node = receiver_node
        @value_node = value_node
        @safe_nav = safe_nav
      end

      def children = [@receiver_node, @value_node].compact

      def evaluate(context)
        implicit = @receiver_node.nil?
        receiver = implicit ? context.frame.the_self : @receiver_node.evaluate(context)
        return Vm::NilObject::NIL if @safe_nav && receiver.is_a?(Vm::NilObject)
        current = receiver.dispatch(context, @read_name, [], {}, nil, private_ok: implicit)
        val = @value_node.evaluate(context)
        result = current.dispatch(context, @operator, [val], {})
        receiver.dispatch(context, @write_name, [result], {}, nil, private_ok: implicit)
        result
      end
    end
  end
end
