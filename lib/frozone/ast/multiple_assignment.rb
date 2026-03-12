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
        # Ruby evaluation order: pre-evaluate LHS receivers/indices (left to right),
        # then evaluate RHS, then perform assignments.
        cached = pre_evaluate_targets(context, @targets)

        rhs = @value_node.evaluate(context)

        # Coerce RHS to array (Ruby semantics: call to_ary if available, even private)
        values =
          if rhs.is_a?(Vm::ArrayObject)
            rhs.raw.dup
          elsif !rhs.is_a?(Vm::NilObject)
            # Check via respond_to?(:to_ary, true) - includes private methods
            has_to_ary = begin
              result = rhs.dispatch(context, :respond_to?, [Vm::SymbolObject.from(:to_ary), Vm::TrueObject::TRUE], {})
              result.truthy?
            rescue
              rhs.lookup_instance_method(:to_ary) ? true : false
            end
            if has_to_ary
              converted = rhs.dispatch(context, :to_ary, [], {}, nil, private_ok: true)
              if converted.is_a?(Vm::NilObject)
                [rhs]
              elsif converted.is_a?(Vm::ArrayObject)
                converted.raw.dup
              else
                raise Vm::FrozoneException.make(:TypeError, "can't convert #{rhs.class_object.name} into Array (to_ary should return Array)")
              end
            else
              [rhs]
            end
          else
            [rhs]
          end

        splat_idx = @targets.index { |t| t[0].to_s.end_with?('_splat') || t[0] == :splat_nil }
        if splat_idx
          pre  = @targets[0...splat_idx]
          post = @targets[(splat_idx + 1)..]

          pre_vals = values[0, pre.length].map { |v| v || Vm::NilObject::NIL }
          post_start = post.length > 0 ? [values.length - post.length, pre.length].max : values.length
          post_vals = post.length > 0 ? (values[post_start..] || []) : []
          post_vals = post_vals.map { |v| v || Vm::NilObject::NIL }
          splat_vals = values[pre.length...post_start] || []
          splat_arr = Vm::ArrayObject.new(splat_vals)

          pre.each_with_index { |t, i| assign(context, t, pre_vals.fetch(i, Vm::NilObject::NIL), cached) }
          assign(context, @targets[splat_idx], splat_arr, cached) unless @targets[splat_idx][0] == :splat_nil
          post.each_with_index { |t, i| assign(context, t, post_vals.fetch(i, Vm::NilObject::NIL), cached) }
        else
          @targets.each_with_index do |t, i|
            assign(context, t, values.fetch(i, Vm::NilObject::NIL), cached)
          end
        end

        rhs
      end

      private

      # Pre-evaluate receivers/indices for :call/:index targets, returning a cache hash
      def pre_evaluate_targets(context, targets)
        cache = {}
        targets.each do |t|
          case t[0]
          when :call, :call_splat
            cache[t.object_id] = t[1].evaluate(context)
          when :index, :index_splat
            receiver = t[1].evaluate(context)
            index_args = t[2].map { |n| n.evaluate(context) }
            cache[t.object_id] = [receiver, index_args]
          when :nested
            # Recursively pre-evaluate nested targets
            sub_cache = pre_evaluate_targets(context, t[1])
            cache.merge!(sub_cache)
          end
        end
        cache
      end

      def assign(context, target, value, cached = {})
        case target[0]
        when :local, :local_splat
          context.frame.frame_at_depth(target[2]).set_local(target[1], value)
        when :ivar, :ivar_splat
          context.frame.the_self.set_ivar(target[1], value)
        when :const, :const_splat
          context.scopes.last.set_constant(target[1], value)
        when :gvar, :gvar_splat
          Vm::GLOBALS[target[1]] = value
        when :cvar_splat
          context.scopes.last.set_class_variable(target[1], value)
        when :index, :index_splat
          receiver, index_args = cached[target.object_id] || [target[1].evaluate(context), target[2].map { |n| n.evaluate(context) }]
          receiver.dispatch(context, :[]=, index_args + [value], {})
        when :call, :call_splat
          receiver = cached[target.object_id] || target[1].evaluate(context)
          receiver.dispatch(context, target[2], [value], {})
        when :const_path
          parent = target[1].evaluate(context)
          parent.set_constant(target[2], value)
        when :cvar
          context.scopes.last.set_class_variable(target[1], value)
        when :nested
          # Recursive destructuring: (a, b) = value
          sub_values = value.is_a?(Vm::ArrayObject) ? value.raw.dup : [value]
          sub_targets = target[1]
          sub_targets.each_with_index do |st, i|
            assign(context, st, sub_values.fetch(i, Vm::NilObject::NIL), cached)
          end
        end
      end
    end
  end
end
