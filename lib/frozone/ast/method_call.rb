require_relative 'node'

module Frozone
  module Ast
    class MethodCall < Node
      attr_reader :name, :receiver_node, :arg_nodes, :kw_arg_nodes, :block_node, :kw_splat_nodes

      def initialize(name, receiver_node, arg_nodes, kw_arg_nodes, block_node = nil, kw_splat_nodes: [], safe_nav: false, ambiguous: false, source_location: nil)
        @name = name
        @receiver_node = receiver_node
        @arg_nodes = arg_nodes
        @kw_arg_nodes = kw_arg_nodes
        @block_node = block_node
        @kw_splat_nodes = kw_splat_nodes
        @safe_nav = safe_nav
        @ambiguous = ambiguous
        @source_location = source_location
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

        has_splat = @arg_nodes.any? { |n| n.is_a?(SplatArg) }
        args = @arg_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end
        kw_args = @kw_arg_nodes.to_h { |kw_node, value_node| [kw_node.evaluate(context).raw, value_node.evaluate(context)] }
        # ruby2_keywords delegation: if call has *splat and last arg is a r2k-marked hash,
        # auto-extract it as keyword arguments (Ruby 2.x compat forwarding).
        if has_splat && kw_args.empty? && args.last.is_a?(Vm::HashObject) && args.last.ruby2_keywords
          r2k = args.pop
          r2k.raw.each { |k, v| kw_args[k.is_a?(Vm::SymbolObject) ? k.raw : k] = v }
        end
        @kw_splat_nodes.each do |splat_node|
          splatted = splat_node.evaluate(context)
          next if splatted.is_a?(Vm::NilObject)  # **nil expands to {} in Ruby 3.4+
          unless splatted.is_a?(Vm::HashObject)
            # Try to_hash coercion (Ruby semantics for **)
            if splatted.is_a?(Vm::ObjectObject)
              begin
                splatted = splatted.dispatch(context, :to_hash, [], {})
              rescue Vm::FrozoneException
                splatted = nil
              end
            end
            unless splatted.is_a?(Vm::HashObject)
              type_name = splatted&.class_object&.name || 'Object'
              raise Vm::FrozoneException.make(:TypeError, "no implicit conversion of #{type_name} into Hash")
            end
          end
          splatted.raw.each { |k, v| kw_args[k.is_a?(Vm::SymbolObject) ? k.raw : k] = v }
        end
        block = @block_node&.evaluate(context)

        # Capture the calling method's frame BEFORE dispatch for BreakException handling.
        # Only set for INLINE block literals (Ast::Block), not block-pass (&b) which is BlockArg.
        calling_method_frame = @block_node.is_a?(Block) ? context.frame.method_frame : nil

        prev_call_site = context.call_site
        context.call_site = @source_location if @source_location
        begin
          receiver.dispatch(context, @name, args, kw_args, block, private_ok: implicit_receiver, implicit_self: implicit_receiver && @ambiguous)
        rescue Ast::BreakException => e
          # Absorb break only if: this call had an inline block AND the break came from that block's context
          raise unless calling_method_frame&.equal?(e.method_frame) ||
                       (calling_method_frame.nil? && e.method_frame.nil? && @block_node.is_a?(Block))
          e.value
        ensure
          context.call_site = prev_call_site
        end
      end
    end
  end
end
