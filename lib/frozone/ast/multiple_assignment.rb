require_relative 'node'

module Frozone
  module Ast
    # Handles `a, b, *c, d = rhs`
    # targets: Array of target descriptors:
    #   [:local, name, depth]
    #   [:local_splat, name, depth]   — the * target
    #   [:ivar, name]
    #   [:ivar_splat, name]
    #   [:const, name]
    #   [:splat_nil]                  — bare `*` (discard)
    class MultipleAssignment < Node
      def initialize(targets, value_node)
        @targets = targets      # Array of target descriptors (validated by parser)
        @value_node = check_type("value_node", value_node, Node)
      end

      def evaluate(context)
        rhs = @value_node.evaluate(context)

        # Coerce RHS to array
        values =
          if rhs.is_a?(Vm::ArrayObject)
            rhs.raw.dup
          else
            [rhs]
          end

        splat_idx = @targets.index { |t| t[0].to_s.end_with?('_splat') || t[0] == :splat_nil }
        if splat_idx
          pre  = @targets[0...splat_idx]
          post = @targets[(splat_idx + 1)..]
          n_fixed = pre.length + post.length

          pre_vals  = values[0, pre.length].map { |v| v || Vm::NilObject::NIL }
          post_vals = post.length > 0 ? (values[-post.length..] || []) : []
          post_vals = post_vals.map { |v| v || Vm::NilObject::NIL }
          splat_end = post.length > 0 ? -(post.length + 1) : -1
          splat_vals = values[pre.length .. splat_end] || []
          splat_arr = Vm::ArrayObject.new(splat_vals)

          pre.each_with_index { |t, i| assign(context, t, pre_vals.fetch(i, Vm::NilObject::NIL)) }
          assign(context, @targets[splat_idx], splat_arr) unless @targets[splat_idx][0] == :splat_nil
          post.each_with_index { |t, i| assign(context, t, post_vals.fetch(i, Vm::NilObject::NIL)) }
        else
          @targets.each_with_index do |t, i|
            assign(context, t, values.fetch(i, Vm::NilObject::NIL))
          end
        end

        rhs
      end

      private

      def assign(context, target, value)
        case target[0]
        when :local, :local_splat
          context.frame.frame_at_depth(target[2]).set_local(target[1], value)
        when :ivar, :ivar_splat
          context.frame.the_self.set_ivar(target[1], value)
        when :const
          context.scopes.last.set_constant(target[1], value)
        end
      end
    end
  end
end
