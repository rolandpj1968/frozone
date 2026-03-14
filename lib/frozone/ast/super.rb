require_relative 'node'

module Frozone
  module Ast
    # super / super() / super(args)
    # forwarding: true  → ForwardingSuperNode (super without parens — passes current method args)
    # forwarding: false → SuperNode (super with explicit args or empty parens)
    class Super < Node
      def initialize(arg_nodes, block_node, forwarding:, kw_splat_nodes: [])
        @arg_nodes       = arg_nodes
        @block_node      = block_node
        @forwarding      = forwarding
        @kw_splat_nodes  = kw_splat_nodes
      end

      def evaluate(context)
        mf = context.frame.method_frame
        current_method = mf.current_method
        raise "super called outside of method" if current_method.nil?

        method_name    = current_method.name
        defining_class = current_method.scopes.last

        receiver = context.frame.the_self
        if receiver.is_a?(Vm::ClassObject)
          # Class method: search in singleton class hierarchy
          klass  = receiver.singleton_class
          origin = defining_class.is_a?(Vm::ClassObject) ? defining_class.singleton_class : defining_class
        else
          # If origin is not in the instance class ancestors, it must be from the singleton chain
          class_ancs = receiver.class_object.ancestors_list
          if class_ancs.any? { |a| a.equal?(defining_class) }
            klass  = receiver.class_object
            origin = defining_class
          else
            klass  = receiver.singleton_class
            origin = defining_class
          end
        end

        super_method = klass.lookup_method_after(method_name, origin)
        if super_method.nil?
          raise Vm::FrozoneException.make(:NoMethodError, "super: no superclass method '#{method_name}' for an instance of #{receiver.class_object.name}")
        end

        args = if @forwarding
          # Read CURRENT values of params from the METHOD frame (not current block/closure frame).
          # super from inside a block/closure forwards the enclosing METHOD's params.
          m = current_method
          if m.respond_to?(:required_params)
            fwd_args = m.required_params.map { |p| mf.get_local(p) }
            m.optional_params.each { |p, _| fwd_args << mf.get_local(p) }
            if m.rest_param
              rest_val = mf.get_local(m.rest_param)
              fwd_args += rest_val.is_a?(Vm::ArrayObject) ? rest_val.raw : [rest_val]
            end
            m.post_params.each { |p| fwd_args << mf.get_local(p) }
            fwd_args
          else
            raise Vm::FrozoneException.make(:RuntimeError, "implicit argument passing of super from method defined by define_method() is not supported. Specify all arguments explicitly.")
          end
        else
          @arg_nodes.flat_map do |n|
            n.is_a?(SplatArg) ? n.evaluate(context).raw : [n.evaluate(context)]
          end
        end

        kw_args = if @forwarding
          m = current_method
          if m.respond_to?(:required_kw_params)
            fwd_kw = {}
            m.required_kw_params.each { |k| fwd_kw[k] = mf.get_local(k) }
            m.optional_kw_params.each { |k, _| fwd_kw[k] = mf.get_local(k) }
            if m.kw_rest_param
              rest_hash = mf.get_local(m.kw_rest_param)
              if rest_hash.is_a?(Vm::HashObject)
                rest_hash.raw.each { |k, v| fwd_kw[k.is_a?(Vm::SymbolObject) ? k.raw : k] = v }
              end
            end
            fwd_kw
          else
            mf.method_kwargs || {}
          end
        else
          result = {}
          @kw_splat_nodes.each do |splat_node|
            splatted = splat_node.evaluate(context)
            next if splatted.is_a?(Vm::NilObject)
            splatted.raw.each { |k, v| result[k.is_a?(Vm::SymbolObject) ? k.raw : k] = v }
          end
          result
        end

        # Ruby always passes the current block to super unless explicitly overridden (&node).
        block = @block_node ? @block_node.evaluate(context) : mf.block

        # For inline block literals, absorb BreakException targeting the calling method frame.
        calling_method_frame = @block_node.is_a?(Block) ? context.frame.method_frame : nil

        begin
          super_method.invoke(context, receiver, args, kw_args, block, from_super: true)
        rescue Ast::BreakException => e
          raise unless calling_method_frame&.equal?(e.method_frame) ||
                       (calling_method_frame.nil? && e.method_frame.nil? && @block_node.is_a?(Block))
          e.value
        end
      end
    end
  end
end
