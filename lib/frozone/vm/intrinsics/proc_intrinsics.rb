# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        def proc_lambda_p(_context, proc_obj) = proc_obj.lambda? ? TrueObject::TRUE : FalseObject::FALSE
        def binding_receiver(_, binding_obj) = binding_obj.captured_frame.the_self

        def proc_set_parameters_override(_, proc_obj, params_arr)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk.respond_to?(:parameters_override=)
            raw = params_arr.raw.map { |p| p.raw.map { |s| s.is_a?(SymbolObject) ? s.raw : s } }
            blk.parameters_override = raw
          end
          proc_obj
        end

        def proc_class_new(context, klass, args)
          raw_args = args.raw
          block = context.frame.block
          proc_klass = Core::OBJECT_CLASS.get_constant(:Proc)
          # If block is already a ProcObject (passed via &proc_arg):
          # - For base Proc class, return identity
          # - For subclasses, create a new instance wrapping the same block
          if block.is_a?(ProcObject)
            if klass.equal?(proc_klass) || klass.equal?(block.class_object)
              return block
            end
            # Subclass: create a new proc of the subclass wrapping the underlying block
            inner_blk = block.block_object
            is_lam = block.lambda?
            proc_obj = ProcObject.new(inner_blk, lambda: is_lam, klass: klass)
            proc_obj.copy_fields_from(block, eigenclass: nil, frozen: false)
            unless klass.equal?(proc_klass)
              begin
                proc_obj.dispatch(context, :initialize, raw_args, {}, nil, private_ok: true)
              rescue FrozoneException => e
                raise unless e.frozone_class_name == :NoMethodError
              end
            end
            return proc_obj
          end
          # No block given — Ruby 4.0: Proc.new always requires an explicit block;
          # block inheritance from calling method was removed.
          if block.nil? || block.is_a?(NilObject)
            raise FrozoneException.make(:ArgumentError, "tried to create Proc object without a block")
          end
          is_lam = block.is_a?(BoundMethodObject) || (block.is_a?(NativeBlock) && block.is_lambda)
          proc_obj = ProcObject.new(block, lambda: is_lam, klass: klass)
          # Call initialize if defined on a subclass
          unless klass.equal?(proc_klass)
            begin
              proc_obj.dispatch(context, :initialize, raw_args, {}, nil, private_ok: true)
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
            end
          end
          proc_obj
        end

        def kernel_proc(context, _receiver)
          block = context.frame.block
          raise FrozoneException.make(:ArgumentError, "tried to create Proc object without a block") if block.nil?
          # Preserve lambda status before unwrapping (proc(&lambda) stays lambda)
          is_lam = block.is_a?(ProcObject) && block.lambda?
          block = block.block_object if block.is_a?(ProcObject)
          ProcObject.new(block, lambda: is_lam)
        end

        def kernel_lambda(context, _receiver)
          block = context.frame.block
          raise FrozoneException.make(:ArgumentError, "tried to create Proc object without a block") if block.nil?
          # If block is already a ProcObject (from &proc_arg), unwrap to its BlockObject
          block = block.block_object if block.is_a?(ProcObject)
          block.make_lambda! if block.is_a?(BlockObject)
          ProcObject.new(block, lambda: true)
        end

        def proc_call(context, proc_obj, args, kw_args_obj = NilObject::NIL)
          blk = context.frame.block
          blk = nil if blk.is_a?(NilObject)
          kw_args = kw_args_obj.is_a?(HashObject) ? kw_args_obj.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k } : {}
          proc_obj.call(context, args.raw, kw_args: kw_args, block: blk)
        end

        def proc_curry(context, proc_obj, arity_arg = NilObject::NIL)
          is_lambda = proc_obj.lambda?
          # Determine the target arity for currying
          base_arity = proc_arity(context, proc_obj).raw
          min_required = base_arity < 0 ? -(base_arity + 1) : base_arity
          # Compute max accepted args (infinity if has splat)
          blk_obj = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk_obj.is_a?(BlockObject)
            has_rest = !blk_obj.rest_param.nil?
            opt_count = blk_obj.optional_params&.length || 0
          elsif blk_obj.is_a?(BoundMethodObject)
            m = blk_obj.raw_method
            m = m.block_obj if m.is_a?(DefinedMethod)
            if m.is_a?(Method) || m.is_a?(BlockObject)
              has_rest = !m.rest_param.nil? && m.rest_param != :__no_rest__
              opt_count = m.optional_params&.length || 0
            else
              has_rest = base_arity < 0
              opt_count = 0
            end
          else
            has_rest = base_arity < 0
            opt_count = 0
          end
          max_accepted = has_rest ? Float::INFINITY : min_required + opt_count

          target = if arity_arg.is_a?(NilObject)
                     min_required
                   else
                     a = arity_arg.raw
                     if is_lambda
                       if a < min_required
                         raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given #{a}, expected #{min_required}+)")
                       end
                       if a > max_accepted
                         raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given #{a}, expected #{min_required}..#{max_accepted == Float::INFINITY ? '*' : max_accepted})")
                       end
                     end
                     a
                   end

          make_curried = lambda do |accumulated|
            NativeBlock.new(
              source_location: nil,
              parameters_override: [[:rest]],
              is_lambda: is_lambda,
              is_curried: true
            ) do |ctx, new_args, block: nil|
              all_args = accumulated + new_args
              if all_args.length >= target
                proc_obj.call(ctx, all_args, block: block)
              else
                ProcObject.new(make_curried.call(all_args), lambda: is_lambda)
              end
            end
          end

          ProcObject.new(make_curried.call([]), lambda: is_lambda)
        end

        def proc_dup(context, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          copy = ProcObject.new(blk, lambda: proc_obj.lambda?, klass: proc_obj.class_object)
          copy.copy_fields_from(proc_obj, eigenclass: nil, frozen: false)
          copy.dispatch(context, :initialize_dup, [proc_obj], {}, nil, private_ok: true)
          copy
        end

        def proc_clone(context, proc_obj, freeze_opt = NilObject::NIL)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          copy = ProcObject.new(blk, lambda: proc_obj.lambda?, klass: proc_obj.class_object)
          sc_copy = proc_obj.eigenclass ? ClassObject.clone_singleton(proc_obj.eigenclass, copy) : nil
          freeze_val = freeze_opt.is_a?(NilObject) ? nil : freeze_opt.truthy?
          frozen = freeze_val == false ? false : freeze_val.nil? ? proc_obj.frozen_object? : true
          copy.copy_fields_from(proc_obj, eigenclass: sc_copy, frozen: frozen)
          copy.dispatch(context, :initialize_clone, [proc_obj], { freeze: frozen ? TrueObject::TRUE : FalseObject::FALSE }, nil, private_ok: true)
          copy
        end

        def proc_ruby2_keywords(context, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk.is_a?(BlockObject)
            has_rest = !blk.rest_param.nil?
            has_post = blk.post_params && !blk.post_params.empty?
            has_kw = !blk.required_kw_params.empty? || !blk.optional_kw_params.empty? || !blk.kw_rest_param.nil?
            if has_rest && !has_post && !has_kw
              blk.ruby2_keywords = true
            else
              reason = if !has_rest
                         "does not accept splat"
                       elsif has_kw
                         "accepts keyword"
                       elsif has_post
                         "accepts post-argument"
                       end
              src = blk.source_location ? " #{blk.source_location[0]}:#{blk.source_location[1]}" : ""
              msg = StringObject.new("warning: Skipping set of ruby2_keywords flag for #{blk.is_lambda ? 'lambda' : 'proc'} at#{src}: #{reason}")
              kernel_warn(context, NilObject::NIL, ArrayObject.new([msg]))
            end
          end
          proc_obj
        end

        def proc_eql(_, p1, p2)
          return FalseObject::FALSE unless p2.is_a?(ProcObject)
          return FalseObject::FALSE unless p1.lambda? == p2.lambda?
          b1 = p1.is_a?(ProcObject) ? p1.block_object : p1
          b2 = p2.is_a?(ProcObject) ? p2.block_object : p2
          b1.equal?(b2) ? TrueObject::TRUE : FalseObject::FALSE
        end

        def proc_hash(_, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          IntegerObject.new(blk.__id__)
        end

        def proc_arity(_, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk.respond_to?(:parameters_override) && blk.parameters_override
            params = blk.parameters_override
            req = params.count { |p| p[0] == :req || p[0] == :keyreq }
            has_rest = params.any? { |p| p[0] == :rest || p[0] == :keyrest }
            return has_rest ? IntegerObject.new(-(req + 1)) : IntegerObject.new(req)
          end
          return bound_method_arity(nil, blk) if blk.is_a?(BoundMethodObject)
          return IntegerObject.new(0) unless blk.is_a?(BlockObject)
          is_lambda = blk.is_lambda
          req = blk.required_params&.length || 0
          opt = blk.optional_params&.length || 0
          rest = blk.rest_param
          post = blk.post_params&.length || 0
          req_kw = blk.required_kw_params&.length || 0
          opt_kw = blk.optional_kw_params&.length || 0
          kw_rest = blk.kw_rest_param
          # Keyword params: required kw count as 1 positional (absorbed from optional kw);
          # optional kw / kw_rest only make arity negative when there are no required kw.
          req_kw_count = req_kw > 0 ? 1 : 0
          kw_optional = req_kw == 0 && (opt_kw > 0 || (kw_rest && kw_rest != :__no_kwargs__))
          # For lambdas, optional positional params and kw_optional make arity negative.
          # For procs, only rest/post make arity negative (opt positional and kw_optional ignored).
          has_opt = rest || post > 0 || (is_lambda && (opt > 0 || kw_optional))
          if has_opt
            IntegerObject.new(-(req + post + req_kw_count + 1))
          else
            IntegerObject.new(req + post + req_kw_count)
          end
        end

        def proc_parameters(_, proc_obj, lambda_override = NilObject::NIL)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk.respond_to?(:parameters_override) && blk.parameters_override
            return ArrayObject.new(blk.parameters_override.map { |p| ArrayObject.new(p.map { |s| SymbolObject.from(s) }) })
          end
          return ArrayObject.new([]) unless blk.is_a?(BlockObject)
          # Determine effective lambda status (may be overridden by lambda: kwarg)
          base_lambda = blk.is_lambda
          is_lambda = if lambda_override.is_a?(NilObject)
                        base_lambda
                      else
                        lambda_override.truthy?
                      end
          # `it` implicit parameter: return [[:req]] for lambda, [[:opt]] for proc (Ruby 4.0+)
          if blk.it_param
            return ArrayObject.new([ArrayObject.new([SymbolObject.from(is_lambda ? :req : :opt)])])
          end
          params = []
          req_type = is_lambda ? :req : :opt
          req_params = blk.required_params || []
          opt_params = blk.optional_params || []
          rest_param = blk.rest_param
          post_params = blk.post_params || []
          req_kw = blk.required_kw_params || []
          opt_kw = blk.optional_kw_params || []
          kw_rest = blk.kw_rest_param
          blk_param = blk.block_param
          req_params.each  { |n| params << param_entry(req_type, n.is_a?(Hash) ? :* : n, for_proc: true) }
          opt_params.each  { |n, _| params << param_entry(:opt, n, for_proc: true) }
          if rest_param || blk.rest_param == :__implicit_rest__
            params << (rest_param ? param_entry(:rest, rest_param, for_proc: true) : ArrayObject.new([SymbolObject.from(:rest)]))
          end
          post_params.each { |n| params << param_entry(req_type, n, for_proc: true) }
          req_kw.each      { |n| params << ArrayObject.new([SymbolObject.from(:keyreq), SymbolObject.from(n)]) }
          opt_kw.each      { |n, _| params << ArrayObject.new([SymbolObject.from(:key), SymbolObject.from(n)]) }
          if kw_rest
            params << if kw_rest == :__no_kwargs__
                        ArrayObject.new([SymbolObject.from(:nokey)])
                      else
                        param_entry(:keyrest, kw_rest, for_proc: true)
                      end
          end
          params << param_entry(:block, blk_param, for_proc: true) if blk_param
          ArrayObject.new(params)
        end

        def proc_source_location(context, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk.is_a?(BlockObject) || blk.is_a?(NativeBlock)
            return NilObject::NIL if blk.respond_to?(:parameters_override) && blk.parameters_override
            loc = blk.source_location
            return NilObject::NIL unless loc
            ArrayObject.new([StringObject.new(loc[0]), IntegerObject.new(loc[1])])
          elsif blk.is_a?(BoundMethodObject)
            result = bound_method_source_location(context, blk)
            # For core library methods (internal), return nil (like C-implemented MRI methods)
            return NilObject::NIL if result.is_a?(ArrayObject) &&
                                     result.raw[0].is_a?(StringObject) && result.raw[0].raw.start_with?('<internal:')
            result
          else
            NilObject::NIL
          end
        end

        def proc_is_curried(_, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          blk.is_a?(NativeBlock) && blk.is_curried ? TrueObject::TRUE : FalseObject::FALSE
        end

        def proc_inspect(context, proc_obj)
          id_str = "0x%x" % proc_obj.__id__
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          is_lam = proc_obj.is_a?(ProcObject) ? proc_obj.lambda? : false
          sym_name = if blk.is_a?(SymbolProcObject)
                       blk.symbol_name
                     elsif blk.is_a?(NativeBlock) && blk.symbol_name
                       blk.symbol_name
                     end
          loc_str = sym_name ? "" : begin
            loc = proc_source_location(context, proc_obj)
            loc.is_a?(ArrayObject) ? " #{loc.raw[0].raw}:#{loc.raw[1].raw}" : ""
          end
          lam_str = is_lam ? " (lambda)" : ""
          sym_str = sym_name ? " (&:#{sym_name})" : ""
          str = "#<Proc:#{id_str}#{loc_str}#{lam_str}#{sym_str}>"
          StringObject.new(str.b)
        end

        def proc_binding(_, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          # A proc created from a Method (via to_proc) wraps a BoundMethodObject.
          # Synthesise a binding whose self is the method's receiver.
          if blk.is_a?(BoundMethodObject)
            scopes = blk.bound_owner ? [blk.bound_owner] : []
            frame = Frame.new(blk.bound_receiver, [], scopes)
            return BindingObject.new(frame)
          end
          frame = blk.is_a?(BlockObject) ? blk.enclosing_frame : nil
          return NilObject::NIL unless frame
          BindingObject.new(frame)
        end

        def binding_local_variables(_, binding_obj)
          all = binding_obj.binding_local_names
          # Filter out numbered params, :it, etc.
          visible = all.reject { |n| n == :it || /\A_[1-9]\z/.match?(n.to_s) }
          ArrayObject.new(visible.map { |n| SymbolObject.from(n) })
        end

        def binding_eval(context, binding_obj, code_obj, filename_arg = NilObject::NIL, lineno_arg = NilObject::NIL)
          kernel_eval(context, NilObject::NIL, code_obj, binding_obj, filename_arg, lineno_arg)
        end

        def binding_coerce_name(name_obj, context)
          if name_obj.is_a?(SymbolObject)
            name_obj.raw
          elsif name_obj.is_a?(StringObject)
            name_obj.raw.to_sym
          else
            result = name_obj.dispatch(context, :to_str, [], {})
            result.raw.to_sym
          end
        end

        def binding_find_frame(frame, name)
          f = frame
          while f
            return f if f.local_names.include?(name)
            f = f.parent_frame
          end
          nil
        end

        def binding_local_variable_get(context, binding_obj, name_obj)
          name = binding_coerce_name(name_obj, context)
          frame = binding_obj.captured_frame
          unless binding_obj.binding_local_names.include?(name)
            raise FrozoneException.make(:NameError, "local variable `#{name}' not defined for #{frame.the_self.inspect}")
          end
          found = binding_find_frame(frame, name)
          raise FrozoneException.make(:NameError, "local variable `#{name}' not defined for #{frame.the_self.inspect}") unless found
          found.get_local(name)
        end

        def binding_local_variable_set(context, binding_obj, name_obj, value)
          name = binding_coerce_name(name_obj, context)
          name_str = name.to_s
          unless name_str.match?(/\A[a-z_][a-zA-Z0-9_]*\z/)
            raise FrozoneException.make(:NameError, "`#{name}' is not allowed as a local variable name")
          end
          frame = binding_obj.captured_frame
          found = binding_find_frame(frame, name)
          if found
            found.set_local(name, value)
            binding_obj.binding_local_names |= [name]
          else
            # New variable: store in shared captured_frame, prepend to this binding's name set only.
            frame.set_local(name, value)
            binding_obj.binding_local_names = [name] + binding_obj.binding_local_names
          end
          value
        end

        def binding_local_variable_defined_q(context, binding_obj, name_obj)
          name = binding_coerce_name(name_obj, context)
          n2f_bool(binding_obj.binding_local_names.include?(name))
        end

        def binding_source_location(_, binding_obj)
          loc = binding_obj.binding_call_site || binding_obj.captured_frame&.incoming_call_site
          return NilObject::NIL unless loc
          parts = loc.split(":")
          return NilObject::NIL unless parts.length >= 2
          ArrayObject.new([StringObject.new(parts[0...-1].join(":")), IntegerObject.new(parts[-1].to_i)])
        end

        def binding_dup(_, binding_obj)
          copy = BindingObject.new(binding_obj.captured_frame, binding_obj.binding_call_site)
          # Override binding_local_names with a COPY (not shared) so new vars added to either
          # binding after the dup don't leak to the other.
          copy.binding_local_names = binding_obj.binding_local_names.dup
          copy.copy_fields_from(binding_obj)
          copy
        end
      end
    end
  end
end
