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

      def children = [*@arg_nodes, *@kw_splat_nodes, @block_node].compact

      def evaluate(context)
        mf = context.frame.method_frame
        current_method = mf.current_method
        raise "super called outside of method" if current_method.nil?

        method_name    = current_method.name
        defining_class = current_method.scopes.last

        receiver = context.frame.the_self

        # Check if the defining_class is a refinement module — super should resolve through
        # the refined class's hierarchy (bypassing the refinement itself).
        is_refinement = defining_class.is_a?(Vm::ModuleObject) &&
                        defining_class.get_ivar(:@__refinement__)&.truthy?

        if is_refinement
          # For refinement methods, super looks up the method in the refined class's hierarchy.
          defining_class.get_ivar(:@__refined_class__)
          klass = receiver.is_a?(Vm::ClassObject) ? receiver.singleton_class : receiver.class_object
          # Use the refined class itself as the "start" point and look from beginning of its hierarchy.
          # We want the first method matching method_name in the class ancestry (not the refinement).
          super_method = klass.lookup_method(method_name)
        elsif receiver.is_a?(Vm::ClassObject)
          # Class method: search in singleton class hierarchy
          klass  = receiver.singleton_class
          # Regular `def self.foo` in class body uses scopes=[Foo] (ClassObject, not singleton),
          # so origin = Foo.singleton_class (look after Foo's singleton class in its MRO).
          # `define_singleton_method` uses scopes=[Foo.singleton_class] (already a singleton),
          # so origin = Foo.singleton_class directly (don't go one level deeper).
          origin = if defining_class.is_a?(Vm::ClassObject) && !defining_class.is_singleton_class
                     defining_class.singleton_class
                   else
                     defining_class
                   end
          super_method = klass.lookup_method_after(method_name, origin)
        else
          # If origin is not in the instance class ancestors, it must be from the singleton chain
          # (or an unbound method from a foreign module bound via UnboundMethod#bind).
          class_ancs = receiver.class_object.ancestors_list
          if class_ancs.any? { |a| a.equal?(defining_class) }
            klass        = receiver.class_object
            origin       = defining_class
            super_method = klass.lookup_method_after(method_name, origin)
          else
            # Foreign-module bind: defining_class is not in receiver's hierarchy at all.
            # Try singleton chain first (covers extend/singleton methods), then fall back to
            # searching the receiver's full class hierarchy (covers UnboundMethod#bind to a
            # class that doesn't include the source module).
            singleton_ancs = receiver.singleton_class.ancestors_list
            if singleton_ancs.any? { |a| a.equal?(defining_class) }
              super_method = receiver.singleton_class.lookup_method_after(method_name, defining_class)
            else
              # Not in any accessible hierarchy — search receiver's class hierarchy from the top.
              super_method = receiver.class_object.lookup_method(method_name)
            end
          end
        end
        args =
          if @forwarding
            # Read CURRENT values of params from the METHOD frame (not current block/closure frame).
            # super from inside a block/closure forwards the enclosing METHOD's params.
            m = current_method
            if m.is_a?(Vm::Method)
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

        # ruby2_keywords delegation: forward r2k-marked last arg as kwargs
        # For explicit super(*args): check if last arg is r2k
        # For forwarding super (zsuper): check if current method is ruby2_keywords
        fwd_method = @forwarding ? (current_method.is_a?(Vm::Method) || current_method.is_a?(Vm::DefinedMethod) ? current_method : nil) : nil
        has_splat = !@forwarding && @arg_nodes.any? { |n| n.is_a?(SplatArg) }
        r2k_kwargs =
          if (has_splat || (fwd_method&.ruby2_keywords)) && @kw_splat_nodes.empty? && args.last.is_a?(Vm::HashObject) && args.last.ruby2_keywords
            r2k = args.pop
            r2k.raw.transform_keys { |k| k.is_a?(Vm::SymbolObject) ? k.raw : k }
          end

        kw_args =
          if @forwarding
            m = current_method
            if m.is_a?(Vm::Method)
              fwd_kw = r2k_kwargs || {}
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
            result = r2k_kwargs || {}
            @kw_splat_nodes.each do |splat_node|
              splatted = splat_node.evaluate(context)
              next if splatted.is_a?(Vm::NilObject)
              splatted.raw.each { |k, v| result[k.is_a?(Vm::SymbolObject) ? k.raw : k] = v }
            end
            result
          end

        if super_method.nil?
          raise Vm::FrozoneException.make(:NoMethodError, "super: no superclass method '#{method_name}' for an instance of #{receiver.class_object.name}")
        elsif super_method == Vm::ClassObject::UNDEF_FOUND
          mm = receiver.lookup_instance_method(:method_missing)
          raise Vm::FrozoneException.make(:NoMethodError, "super: no superclass method '#{method_name}' for an instance of #{receiver.class_object.name}") unless mm
          block = @block_node ? @block_node.evaluate(context) : mf.block
          return mm.invoke(context, receiver, [Vm::SymbolObject.from(method_name)] + args, kw_args, block)
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
