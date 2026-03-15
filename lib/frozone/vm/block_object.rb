module Frozone
  module Vm
    class BlockObject
      # auto_splat: true for procs/blocks (not lambdas), causes single Array arg to be
      # auto-splatted when block expects multiple positional args
      # is_lambda: true for lambdas (strict arg count checking, no auto-splat)
      attr_reader :source_location
      attr_reader :required_params, :optional_params, :rest_param, :post_params
      attr_reader :required_kw_params, :optional_kw_params, :kw_rest_param, :block_param

      def initialize(required_params, optional_params, rest_param, post_params,
                     required_kw_params, optional_kw_params, kw_rest_param,
                     block_param, auto_splat, locals, body, enclosing_frame,
                     is_lambda: false, it_param: false, source_location: nil)
        @required_params     = required_params
        @optional_params     = optional_params
        @rest_param          = rest_param
        @post_params         = post_params
        @required_kw_params  = required_kw_params
        @optional_kw_params  = optional_kw_params
        @kw_rest_param       = kw_rest_param
        @block_param         = block_param
        @auto_splat          = auto_splat
        @is_lambda           = is_lambda
        @it_param            = it_param
        @locals              = locals
        @body                = body
        @enclosing_frame     = enclosing_frame
        @source_location     = source_location # [file, line] or nil
      end

      def lambda? = @is_lambda

      def make_lambda!
        @is_lambda = true
        @auto_splat = false
      end

      def invoke(context, args, kw_args: {}, receiver: nil, block: nil, instance_eval_receiver: nil, def_scope: nil, current_method: nil, as_method: false, thread_boundary: false)
        the_self = receiver || @enclosing_frame.the_self
        new_frame = Frame.new(
          the_self,
          @locals,
          @enclosing_frame.scopes,
          @enclosing_frame
        )

        # Block auto-splat: when called with single arg and block expects multiple
        if @auto_splat && args.length == 1
          arg = args[0]
          if arg.is_a?(ArrayObject)
            args = arg.raw
          elsif !arg.is_a?(NilObject)
            # Call respond_to?(:to_ary, true) via dispatch (includes private); rescue for BasicObject
            has_to_ary = begin
              result = arg.dispatch(context, :respond_to?, [SymbolObject.from(:to_ary), TrueObject::TRUE], {})
              result.truthy?
            rescue
              arg.lookup_instance_method(:to_ary) ? true : false
            end
            if has_to_ary
              converted = arg.dispatch(context, :to_ary, [], {})
              if converted.is_a?(ArrayObject)
                args = converted.raw
              elsif !converted.is_a?(NilObject)
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{arg.class_object.name} into Array")
              end
            end
          end
        end

        # **nil parameter: reject any keyword arguments (check before populate_params)
        if @kw_rest_param == :__no_kwargs__ && !kw_args.empty?
          raise FrozoneException.make(:ArgumentError, "no keywords accepted")
        end

        # If block has no keyword params, convert any kw_args to a positional Hash (Ruby semantics).
        if !kw_args.empty? && @required_kw_params.empty? && @optional_kw_params.empty? && @kw_rest_param.nil?
          hash_val = HashObject.new(kw_args.transform_keys { |k| k.is_a?(Symbol) ? SymbolObject.from(k) : k })
          args = args + [hash_val]
          kw_args = {}
        end

        if @block_param
          proc_obj = if block.is_a?(ProcObject)
                       block
                     elsif block && !block.is_a?(NilObject)
                       ProcObject.new(block)
                     else
                       NilObject::NIL
                     end
          new_frame.set_local(@block_param, proc_obj)
        end

        # Propagate enclosing method's block so `yield` inside a block calls the outer block.
        # But only if not explicitly overridden.
        new_frame.block = block || @enclosing_frame.block
        if @is_lambda || as_method
          # Lambdas and define_method-invoked blocks act like methods.
          new_frame.method_frame = new_frame
        else
          # `return` inside a block exits the enclosing method, not the method that invoked yield.
          new_frame.method_frame = @enclosing_frame.method_frame
        end

        new_frame.def_scope = def_scope || instance_eval_receiver&.singleton_class
        new_frame.current_method = current_method if current_method
        new_frame.incoming_call_site = context&.call_site
        new_frame.thread_boundary = thread_boundary && !@is_lambda

        # Push frame BEFORE populating params so default expressions evaluate with
        # correct `self` (enclosing scope's self, not the proc/block caller's frame).
        context.push_frame(new_frame)
        begin
          populate_params(context, new_frame, args)
          populate_kw_params(context, new_frame, kw_args)
          loop do
            begin
              return @body.evaluate(context)
            rescue Ast::RedoException
              # redo: re-run body with same args
            end
          end
        rescue Ast::ReturnException => e
          if (@is_lambda || as_method) && e.method_frame.equal?(new_frame)
            # Lambdas and define_method-invoked blocks catch their own return.
            e.value
          else
            # Procs/blocks: propagate return to exit the enclosing method.
            raise
          end
        rescue Ast::NextException => e
          e.value
        rescue Ast::BreakException => e
          if @is_lambda && e.method_frame&.equal?(new_frame)
            e.value  # break directly in lambda exits the lambda (like return)
          else
            e.from_block = true
            raise
          end
        ensure
          context.pop_frame
        end
      end

      private

      def populate_params(context, frame, args)
        n_req  = @required_params.length
        n_post = @post_params.length
        n_opt  = @optional_params.length

        if @is_lambda
          # Lambdas have strict argument checking
          n_min = n_req + n_post
          n_max = n_req + n_opt + n_post
          if args.length < n_min
            raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given #{args.length}, expected #{n_min}#{n_opt > 0 || @rest_param ? '+' : ''})")
          end
          unless @rest_param
            if args.length > n_max
              raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given #{args.length}, expected #{n_min == n_max ? n_min : "#{n_min}..#{n_max}"})")
            end
          end
        else
          # Cap effective args at total param slots (excess args are ignored in blocks)
          unless @rest_param
            effective_len = [args.length, n_req + n_opt + n_post].min
            args = args[0, effective_len] if args.length > effective_len
          end
        end

        # post_start: where post params begin in args array
        # If fewer args than post params, start from 0 (fill left-to-right, trailing get nil)
        post_start = [args.length - n_post, n_req].max

        # Fill required params from front (lenient: missing → nil)
        @required_params.each_with_index do |param, i|
          val = args.fetch(i, NilObject::NIL)
          assign_param(context, frame, param, val)
        end

        # Fill post params starting at post_start (lenient: missing → nil)
        @post_params.each_with_index do |param, i|
          val = args.fetch(post_start + i, NilObject::NIL)
          assign_param(context, frame, param, val)
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
        missing = []
        @required_kw_params.each do |kw|
          if kw_args.key?(kw)
            frame.set_local(kw, kw_args.delete(kw))
          else
            missing << kw
          end
        end
        unless missing.empty?
          label = missing.length == 1 ? "keyword" : "keywords"
          raise FrozoneException.make(:ArgumentError, "missing #{label}: #{missing.map { |k| ":#{k}" }.join(', ')}")
        end

        @optional_kw_params.each do |kw, value_node|
          value = kw_args.key?(kw) ? kw_args.delete(kw) : value_node.evaluate(context)
          frame.set_local(kw, value)
        end

        if @kw_rest_param == :__no_kwargs__
          unless kw_args.empty?
            raise FrozoneException.make(:ArgumentError, "no keywords accepted")
          end
        elsif @kw_rest_param
          kw_rest = kw_args.transform_keys { |k| k.is_a?(Symbol) ? SymbolObject.from(k) : k }
          frame.set_local(@kw_rest_param, HashObject.new(kw_rest))
        end
      end

      # Assign a single param (Symbol or nested Hash) to frame given a value.
      def assign_param(context, frame, param, val)
        if param.is_a?(Hash)
          # Destructuring: |(a, b)| or |(a, *b, c)| — possibly nested
          sub_args = coerce_to_array(context, val)
          sub_names  = param[:names]
          sub_rest   = param[:rest]
          sub_rights = param[:rights] || []
          sub_names.each_with_index  { |n, j| assign_param(context, frame, n, sub_args.fetch(j, NilObject::NIL)) }
          if sub_rest
            rest_end  = sub_rights.length > 0 ? -(sub_rights.length + 1) : -1
            rest_vals = sub_args[sub_names.length..rest_end] || []
            frame.set_local(sub_rest, ArrayObject.new(rest_vals))
          end
          rights_start = [sub_args.length - sub_rights.length, sub_names.length].max
          sub_rights.each_with_index { |n, j| assign_param(context, frame, n, sub_args.fetch(rights_start + j, NilObject::NIL)) }
        else
          frame.set_local(param, val)
        end
      end

      def coerce_to_array(context, val)
        return val.raw if val.is_a?(ArrayObject)
        return [val] if val.is_a?(NilObject)
        has_to_ary = begin
          result = val.dispatch(context, :respond_to?, [SymbolObject.from(:to_ary), TrueObject::TRUE], {})
          result.truthy?
        rescue
          val.lookup_instance_method(:to_ary) ? true : false
        end
        if has_to_ary
          converted = val.dispatch(context, :to_ary, [], {})
          return converted.raw if converted.is_a?(ArrayObject)
          return [val] if converted.is_a?(NilObject)
          raise FrozoneException.make(:TypeError, "no implicit conversion of #{val.class_object.name} into Array")
        end
        [val]
      end
    end
  end
end
