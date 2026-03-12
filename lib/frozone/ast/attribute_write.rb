require_relative 'node'

module Frozone
  module Ast
    # a.foo = val or a[i] = val — calls setter but returns the assigned value (not setter result)
    # Ruby semantics: the value of `a.foo = val` is `val`, regardless of what `foo=` returns
    class AttributeWrite < Node
      def initialize(name, receiver_node, arg_nodes, kw_arg_nodes, safe_nav: false)
        @name          = name
        @receiver_node = receiver_node
        @arg_nodes     = arg_nodes
        @kw_arg_nodes  = kw_arg_nodes
        @safe_nav      = safe_nav
      end

      def evaluate(context)
        implicit_receiver = @receiver_node.nil?
        receiver = implicit_receiver ? context.frame.the_self : @receiver_node.evaluate(context)

        return Vm::NilObject::NIL if @safe_nav && receiver.is_a?(Vm::NilObject)

        args = @arg_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        kw_args = @kw_arg_nodes.to_h { |kw_node, value_node| [kw_node.evaluate(context).raw, value_node.evaluate(context)] }

        # Return value is the last argument (the RHS value), not the setter's return
        return_value = args.last

        receiver.dispatch(context, @name, args, kw_args, nil, private_ok: implicit_receiver)

        return_value
      end
    end
  end
end
