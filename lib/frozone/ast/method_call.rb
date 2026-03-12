require_relative 'node'

module Frozone
  module Ast
    class MethodCall < Node
      attr_reader :name, :receiver_node, :arg_nodes, :kw_arg_nodes, :block_node, :kw_splat_nodes

      def initialize(name, receiver_node, arg_nodes, kw_arg_nodes, block_node = nil, kw_splat_nodes: [], safe_nav: false)
        @name = name
        @receiver_node = receiver_node
        @arg_nodes = arg_nodes
        @kw_arg_nodes = kw_arg_nodes
        @block_node = block_node
        @kw_splat_nodes = kw_splat_nodes
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
          next if splatted.is_a?(Vm::NilObject)  # **nil expands to {} in Ruby 3.4+
          unless splatted.is_a?(Vm::HashObject)
            raise Vm::FrozoneException.make(:TypeError, "no implicit conversion of #{splatted.class_object.name} into Hash")
          end
          splatted.raw.each { |k, v| kw_args[k.is_a?(Vm::SymbolObject) ? k.raw : k] = v }
        end
        block = @block_node&.evaluate(context)

        # Capture the calling method's frame BEFORE dispatch for BreakException handling.
        # Only set for INLINE block literals (Ast::Block), not block-pass (&b) which is BlockArg.
        calling_method_frame = @block_node.is_a?(Block) ? context.frame.method_frame : nil

        begin
          receiver.dispatch(context, @name, args, kw_args, block, private_ok: implicit_receiver)
        rescue Ast::BreakException => e
          # Absorb break only if: this call had an inline block AND the break came from that block's context
          raise unless calling_method_frame&.equal?(e.method_frame) ||
                       (calling_method_frame.nil? && e.method_frame.nil? && @block_node.is_a?(Block))
          e.value
        end
      end
    end
  end
end
