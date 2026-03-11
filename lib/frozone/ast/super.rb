require_relative 'node'

module Frozone
  module Ast
    # super / super() / super(args)
    # forwarding: true  → ForwardingSuperNode (super without parens — passes current method args)
    # forwarding: false → SuperNode (super with explicit args or empty parens)
    class Super < Node
      def initialize(arg_nodes, block_node, forwarding:)
        @arg_nodes   = check_array_type("arg_nodes", arg_nodes, Node)
        @block_node  = check_nil_or_type("block_node", block_node, Node)
        @forwarding  = forwarding
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
          klass  = receiver.class_object
          origin = defining_class
        end

        super_method = klass.lookup_method_after(method_name, origin)
        if super_method.nil?
          raise Vm::FrozoneException.make(:NoMethodError, "super: no superclass method '#{method_name}' for an instance of #{receiver.class_object.name}")
        end

        args = if @forwarding
          mf.method_args || []
        else
          @arg_nodes.flat_map do |n|
            n.is_a?(SplatArg) ? n.evaluate(context).raw : [n.evaluate(context)]
          end
        end

        block = @block_node ? @block_node.evaluate(context) : (mf.block if @forwarding)

        super_method.invoke(context, receiver, args, {}, block)
      end
    end
  end
end
