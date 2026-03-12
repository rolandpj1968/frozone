require_relative 'node'

module Frozone
  module Ast
    class MethodCall < Node
      def initialize(name, receiver_node, arg_nodes, kw_arg_nodes, block_node = nil, kw_splat_nodes: [], safe_nav: false)
        @name = check_type("name", name, Symbol)
        @receiver_node = check_nil_or_type("receiver_node", receiver_node, Node)
        @arg_nodes = check_array_type("arg_nodes", arg_nodes, Node)
        @kw_arg_nodes = check_hash_of_types("kw_arg_nodes", kw_arg_nodes, Node, Node)
        @block_node = check_nil_or_type("block_node", block_node, Node)
        @kw_splat_nodes = check_array_type("kw_splat_nodes", kw_splat_nodes, Node)
        @safe_nav = safe_nav
      end

      def to_s
        "call(#{@name}, #{@receiver_node || '_'}, #{@arg_nodes.map(&:to_s).join(', ')})"
      end

      def evaluate(context)
        implicit_receiver = @receiver_node.nil?
        receiver =
          if implicit_receiver
            context.frame.the_self
          else
            @receiver_node.evaluate(context)
          end

        return Vm::NilObject::NIL if @safe_nav && receiver.is_a?(Vm::NilObject)

        args = @arg_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        kw_args = @kw_arg_nodes.to_h { |kw_node, value_node| [kw_node.evaluate(context).raw, value_node.evaluate(context)] }
        @kw_splat_nodes.each do |splat_node|
          splatted = splat_node.evaluate(context)
          splatted.raw.each { |k, v| kw_args[k.is_a?(Vm::SymbolObject) ? k.raw : k] = v }
        end
        block = @block_node&.evaluate(context)

        receiver.dispatch(context, @name, args, kw_args, block, private_ok: implicit_receiver)
      end
    end
  end
end
