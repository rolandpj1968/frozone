require_relative 'node'

module Frozone
  module Ast
    # rescue => obj.setter  — calls obj.setter=(value)
    class RescueCallTarget
      def initialize(receiver_node, setter_name, safe_nav = false)
        @receiver_node = receiver_node  # nil means implicit self
        @setter_name = setter_name    # Symbol, e.g. :foo=
        @safe_nav = safe_nav
      end

      def store(context, value)
        receiver = @receiver_node ? @receiver_node.evaluate(context) : context.frame.the_self
        # Safe navigation: skip if receiver is nil
        return value if @safe_nav && receiver.is_a?(Vm::NilObject)
        receiver.dispatch(context, @setter_name, [value], {}, nil, private_ok: @receiver_node.nil?)
        value
      end
    end

    # rescue => obj[*args]  — calls obj[]=(args..., value)
    class RescueIndexTarget
      def initialize(receiver_node, arg_nodes)
        @receiver_node = receiver_node
        @arg_nodes = arg_nodes
      end

      def store(context, value)
        receiver = @receiver_node ? @receiver_node.evaluate(context) : context.frame.the_self
        index_args = @arg_nodes.flat_map do |a|
          a.is_a?(SplatArg) ? a.evaluate(context).raw : [a.evaluate(context)]
        end
        receiver.dispatch(context, :[]=, index_args + [value], {}, nil, private_ok: @receiver_node.nil?)
        value
      end
    end
  end
end
