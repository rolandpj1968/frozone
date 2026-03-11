module Frozone
  module Vm
    class BlockObject
      # auto_splat: true for procs/blocks (not lambdas), causes single Array arg to be
      # auto-splatted when block expects multiple positional args
      def initialize(required_params, optional_params, rest_param, post_params,
                     required_kw_params, optional_kw_params, kw_rest_param,
                     block_param, auto_splat, locals, body, enclosing_frame)
        @required_params     = required_params
        @optional_params     = optional_params
        @rest_param          = rest_param
        @post_params         = post_params
        @required_kw_params  = required_kw_params
        @optional_kw_params  = optional_kw_params
        @kw_rest_param       = kw_rest_param
        @block_param         = block_param
        @auto_splat          = auto_splat
        @locals              = locals
        @body                = body
        @enclosing_frame     = enclosing_frame
      end

      def invoke(context, args, kw_args: {}, receiver: nil, block: nil)
        new_frame = Frame.new(
          receiver || @enclosing_frame.the_self,
          @locals,
          @enclosing_frame.scopes,
          @enclosing_frame
        )

        # Block auto-splat: when called with single arg and block expects multiple
        if @auto_splat && args.length == 1
          arg = args[0]
          if arg.is_a?(ArrayObject)
            args = arg.raw
          elsif !arg.is_a?(NilObject) && arg.lookup_instance_method(:to_ary)
            # Try to_ary conversion for auto-splat
            converted = arg.dispatch(context, :to_ary, [], {})
            if converted.is_a?(ArrayObject)
              args = converted.raw
            elsif !converted.is_a?(NilObject)
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{arg.class_object.name} into Array")
            end
          end
        end

        populate_params(context, new_frame, args)
        populate_kw_params(context, new_frame, kw_args)

        if @block_param
          proc_obj = block ? ProcObject.new(block) : NilObject::NIL
          new_frame.set_local(@block_param, proc_obj)
        end

        # Propagate enclosing method's block so `yield` inside a block calls the outer block.
        # But only if not explicitly overridden.
        new_frame.block = block || @enclosing_frame.block
        # `return` inside a block exits the enclosing method, not the method that invoked yield.
        new_frame.method_frame = @enclosing_frame.method_frame

        context.push_frame(new_frame)
        begin
          loop do
            begin
              return @body.evaluate(context)
            rescue Ast::RedoException
              # redo: re-run body with same args
            end
          end
        rescue Ast::ReturnException => e
          # If there's no enclosing method (method_frame nil), absorb return as a block return.
          # Otherwise re-raise so the enclosing Method#invoke can catch it.
          raise unless e.method_frame.nil?
          e.value
        rescue Ast::NextException => e
          e.value
        rescue Ast::BreakException => e
          e.from_block = true
          raise
        ensure
          context.pop_frame
        end
      end

      private

      def populate_params(context, frame, args)
        n_req  = @required_params.length
        n_post = @post_params.length
        n_opt  = @optional_params.length

        # post_start: where post params begin in args array
        # If fewer args than post params, start from 0 (fill left-to-right, trailing get nil)
        post_start = [args.length - n_post, n_req].max

        # Fill required params from front (lenient: missing → nil)
        @required_params.each_with_index do |param, i|
          val = args.fetch(i, NilObject::NIL)
          if param.is_a?(Hash)
            # Destructuring: |(a, b)| or |(a, *b, c)|
            sub_args = if val.is_a?(ArrayObject)
              val.raw
            elsif !val.is_a?(NilObject) && val.lookup_instance_method(:to_ary)
              converted = val.dispatch(context, :to_ary, [], {})
              if converted.is_a?(ArrayObject)
                converted.raw
              elsif converted.is_a?(NilObject)
                [val]
              else
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{val.class_object.name} into Array")
              end
            else
              [val]
            end
            sub_names  = param[:names]
            sub_rest   = param[:rest]
            sub_rights = param[:rights] || []
            n_fixed = sub_names.length + sub_rights.length
            sub_names.each_with_index { |n, j| frame.set_local(n, sub_args.fetch(j, NilObject::NIL)) }
            if sub_rest
              rest_end = sub_rights.length > 0 ? -(sub_rights.length + 1) : -1
              rest_vals = sub_args[sub_names.length..rest_end] || []
              frame.set_local(sub_rest, ArrayObject.new(rest_vals))
            end
            sub_rights.each_with_index { |n, j| frame.set_local(n, sub_args.fetch(-(sub_rights.length - j), NilObject::NIL)) }
          else
            frame.set_local(param, val)
          end
        end

        # Fill post params starting at post_start (lenient: missing → nil)
        @post_params.each_with_index do |name, i|
          frame.set_local(name, args.fetch(post_start + i, NilObject::NIL))
        end

        # Fill optional params from the middle region (between required and post_start)
        n_middle = [post_start - n_req, 0].max
        @optional_params.each_with_index do |(name, default_node), i|
          value = i < n_middle ? args[n_req + i] : default_node.evaluate(context)
          frame.set_local(name, value)
        end

        # Fill rest param
        unless @rest_param.nil?
          filled_opt = [n_middle, n_opt].min
          rest_start = n_req + filled_opt
          rest_end   = post_start - 1
          rest_items = rest_end >= rest_start ? (args[rest_start..rest_end] || []) : []
          frame.set_local(@rest_param, ArrayObject.new(rest_items))
        end
      end

      def populate_kw_params(context, frame, kw_args)
        @required_kw_params.each do |kw|
          next unless kw_args.key?(kw)
          frame.set_local(kw, kw_args.delete(kw))
        end

        @optional_kw_params.each do |kw, value_node|
          value = kw_args.key?(kw) ? kw_args.delete(kw) : value_node.evaluate(context)
          frame.set_local(kw, value)
        end

        unless @kw_rest_param.nil?
          kw_rest = kw_args.transform_keys { |k| k.is_a?(Symbol) ? SymbolObject.from(k) : k }
          frame.set_local(@kw_rest_param, HashObject.new(kw_rest))
        end
      end
    end
  end
end
