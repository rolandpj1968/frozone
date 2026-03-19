# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Kernel (on Object for now)
        def kernel_puts(context, _receiver, args)
          if args.raw.empty?
            $stdout.puts
          else
            args.raw.each { |a| $stdout.puts(a.dispatch(context, :to_s, [], {}).raw) }
          end
          NilObject::NIL
        end

        def kernel_print(context, _receiver, args)
          args.raw.each { |a| $stdout.print(a.dispatch(context, :to_s, [], {}).raw) }
          NilObject::NIL
        end

        def kernel_warn(context, _receiver, args)
          stderr_vm = GLOBALS[:"$stderr"]
          strs = args.raw.map { |a| a.dispatch(context, :to_s, [], {}) }
          if strs.empty?
            stderr_vm.dispatch(context, :puts, [], {})
          else
            stderr_vm.dispatch(context, :puts, strs, {})
          end
          NilObject::NIL
        end

        # Emit a verbose-only warning (e.g. "given block not used") with the caller's call-site.
        # Uses the incoming_call_site of the current frame (where the Ruby method was called from).
        # Output format: "file:line: warning: msg"
        def kernel_verbose_warn(context, _receiver, msg_obj)
          verbose = GLOBALS.fetch(:"$VERBOSE", FalseObject::FALSE).truthy?
          return NilObject::NIL unless verbose
          msg = msg_obj.is_a?(StringObject) ? msg_obj.raw : msg_obj.dispatch(context, :to_s, [], {}).raw
          location = context.frame&.incoming_call_site
          Frozone::Vm.emit_warning(context, msg, location: location)
          NilObject::NIL
        end

        # Emit an unconditional warning with the caller's call-site (for deprecation warnings).
        # Output format: "file:line: warning: msg"
        def kernel_deprecation_warn(context, _receiver, msg_obj)
          msg = msg_obj.is_a?(StringObject) ? msg_obj.raw : msg_obj.dispatch(context, :to_s, [], {}).raw
          location = context.frame&.incoming_call_site
          Frozone::Vm.emit_warning(context, msg, location: location)
          NilObject::NIL
        end

        def kernel_raise(context, _receiver, msg = NilObject::NIL, message_arg = NilObject::NIL, backtrace_arg = NilObject::NIL, cause_arg = NilObject::NIL)
          current_exc = GLOBALS[:"$!"]
          no_cause_sentinel = cause_arg.is_a?(SymbolObject) && cause_arg.raw == :__raise_no_cause__
          explicit_cause = !cause_arg.is_a?(NilObject) && !no_cause_sentinel

          # Distinguish bare `raise` (no args → :__raise_no_arg__ sentinel) from `raise(nil)` (explicit nil → TypeError)
          no_arg_sentinel = msg.is_a?(SymbolObject) && msg.raw == :__raise_no_arg__

          # ArgumentError: only cause: given with no positional args
          raise FrozoneException.make(:ArgumentError, "only cause is given with no arguments") if no_arg_sentinel && explicit_cause

          # Validate explicit cause type before building exception
          if explicit_cause && !cause_arg.is_a?(NilObject)
            raise FrozoneException.make(:TypeError, "exception object expected") unless exception_instance?(cause_arg)
          end

          cause = if no_cause_sentinel
                    (current_exc && !current_exc.is_a?(NilObject)) ? current_exc : nil
                  elsif cause_arg.is_a?(NilObject)
                    nil
                  else
                    cause_arg
                  end

          if no_arg_sentinel
            reraise_current_or_runtime(cause, context)
          elsif msg.is_a?(ClassObject) || msg.is_a?(ModuleObject)
            raise_from_exception_class(context, msg, message_arg, backtrace_arg, cause)
          elsif msg.is_a?(StringObject) && message_arg.is_a?(NilObject)
            raise_from_string(context, msg, backtrace_arg, cause)
          else
            raise_from_exception_protocol(context, msg, message_arg, backtrace_arg, cause)
          end
        end

        def kernel_caller_locations(context, _receiver, start_obj = NilObject::NIL, length_obj = NilObject::NIL)
          start  = start_obj.is_a?(IntegerObject)  ? start_obj.raw : 1
          length = length_obj.is_a?(IntegerObject) ? length_obj.raw : nil
          frames = collect_caller_frames(context, :caller_locations)

          location_class = Core::OBJECT_CLASS.get_constant(:Thread)&.get_constant(:Backtrace)&.get_constant(:Location)
          entries = frames.map do |call_site, meth|
            str_obj = StringObject.new("#{call_site}:in '#{meth}'", frozen: true)
            if location_class
              location_class.dispatch(context, :_from_string, [str_obj], {}, nil, private_ok: true)
            else
              str_obj
            end
          end

          sliced = length ? entries[start, length] : entries[start..]
          ArrayObject.new(sliced || [])
        end

        # Build the Ruby caller() array from the current frame stack.
        # `start` — how many logical entries to skip (0 = include the frame that called caller)
        # `length` — max entries to return (nil = all)
        def kernel_caller(context, _receiver, start_obj = NilObject::NIL, length_obj = NilObject::NIL)
          start  = start_obj.is_a?(IntegerObject)  ? start_obj.raw : 1
          length = length_obj.is_a?(IntegerObject) ? length_obj.raw : nil
          frames = collect_caller_frames(context, :caller)

          entries = frames.map do |call_site, meth|
            StringObject.new("#{call_site}:in '#{meth}'", frozen: true)
          end

          # Apply start offset and length
          sliced = length ? entries[start, length] : entries[start..]
          ArrayObject.new(sliced || [])
        end

        def signal_trap(context, signal, block_arg = NilObject::NIL)
          # Stub: signal trapping not fully implemented
          NilObject::NIL
        end

        def kernel_p(context, _receiver, args)
          args.raw.each { |a| $stdout.puts(a.dispatch(context, :inspect, [], {}).raw) }
          args.raw.length == 1 ? args.raw.first : args
        end

        SEND_TRANSPARENT_CALLEE_NAMES = %i[send __send__ public_send].freeze

        def kernel__method__(context, _receiver)
          frames = context.frames
          # Start at frames[-2]: the frame that contains the __method__ call.
          # For blocks, method_frame points to the enclosing method's frame (definition site).
          # For methods, method_frame points to the method frame itself.
          # Skip transparent dispatch methods (send/__send__/public_send).
          i = frames.length - 2
          while i >= 0
            mf = frames[i].method_frame
            return NilObject::NIL unless mf
            m = mf.current_method
            return NilObject::NIL unless m
            callee = mf.callee_name
            unless callee && SEND_TRANSPARENT_CALLEE_NAMES.include?(callee)
              return SymbolObject.from(m.name)
            end
            i -= 1
          end
          NilObject::NIL
        end

        def kernel__callee__(context, _receiver)
          # __callee__ returns the callee name of the innermost non-transparent method frame.
          # send/__send__/public_send are transparent: skip them and look at the calling method.
          frames = context.frames
          i = frames.length - 2
          while i >= 0
            mf = frames[i].method_frame
            return NilObject::NIL unless mf
            cn = mf.callee_name
            break unless cn && SEND_TRANSPARENT_CALLEE_NAMES.include?(cn)
            i -= 1
          end
          return NilObject::NIL if i < 0
          mf = frames[i].method_frame
          return NilObject::NIL unless mf
          cn = mf.callee_name
          cn ? SymbolObject.from(cn) : NilObject::NIL
        end

        def kernel_block_given(context, _receiver)
          # block_given? is a Ruby method call (adds one frame), so check the
          # CALLING frame (one below current) to find the actual method's block.
          frames = context.frames
          caller_frame = frames.length >= 2 ? frames[-2] : nil
          b = caller_frame&.block
          bool_object_for(!b.nil? && !b.is_a?(NilObject))
        end

        def kernel_loop(context, _receiver, block)
          return NilObject::NIL if block.is_a?(NilObject)
          loop do
            block.invoke(context, [])
          rescue Ast::BreakException => e
            return e.value
          end
          NilObject::NIL
        end

        def kernel_catch(context, _receiver, tag, block)
          tag_raw = tag.is_a?(NilObject) ? :__catch_nil__ : tag.respond_to?(:raw) ? tag.raw : tag
          return NilObject::NIL if block.is_a?(NilObject)
          result = catch(tag_raw) { block.invoke(context, [tag]) }
          result.is_a?(ObjectObject) ? result : NilObject::NIL
        end

        def kernel_throw(_, _receiver, tag, value = NilObject::NIL)
          # In Ruby, throw with a String tag raises ArgumentError
          if tag.is_a?(StringObject)
            raise FrozoneException.make(:ArgumentError, "no implicit conversion of String into Symbol")
          end
          tag_raw = tag.respond_to?(:raw) ? tag.raw : tag
          begin
            throw(tag_raw, value)
          rescue UncaughtThrowError => e
            exc = FrozoneException.make(:UncaughtThrowError, e.message)
            exc.vm_object.set_ivar(:@tag, tag)
            raise exc
          end
        end

        # Bundler reinitialization warnings appear in subprocess output when running under bundle exec.
        BUNDLER_NOISE_RE = %r{\A.+(?:bundler/rubygems_ext\.rb|rubygems/platform\.rb):\d+: warning: (?:already initialized constant|previous definition of) }

        def kernel_backtick(_, _receiver, cmd_obj)
          result = `#{cmd_obj.raw}`
          GLOBALS[:"$?"] = ProcessStatusObject.new($?)
          filtered = result.lines.reject { |l| BUNDLER_NOISE_RE.match?(l) }.join
          StringObject.new(filtered)
        end

        def process_status_exitstatus(_, obj) = IntegerObject.new(obj.native_status.exitstatus || 0)

        def process_status_pid(_, obj) = IntegerObject.new(obj.native_status.pid || 0)

        def process_status_termsig(_, obj)
          sig = obj.native_status.termsig
          sig ? IntegerObject.new(sig) : NilObject::NIL
        end

        def emit_vm_warning(context, msg) = Frozone::Vm.emit_warning(context, msg)

        def kernel_abort(context, _receiver, msg)
          m = msg.is_a?(NilObject) ? nil : msg.dispatch(context, :to_s, [], {}).raw
          $stderr.puts(m) if m
          exit(1)
        end

        def kernel_exit(_, _receiver, code)
          status = code.is_a?(TrueObject) ? 0 : code.is_a?(FalseObject) ? 1 : code.is_a?(IntegerObject) ? code.raw : 0
          exc_class = Core::OBJECT_CLASS.get_constant(:SystemExit)
          exc_obj = ObjectObject.new(exc_class)
          exc_obj.set_ivar(:@status, IntegerObject.new(status))
          exc_obj.set_ivar(:@message, StringObject.new("exit"))
          raise FrozoneException.new(exc_obj, "exit")
        end

        def kernel_rand(context, _receiver, n) = random_rand(context, nil, n)

        def kernel_srand(_, _receiver, seed)
          result = srand(seed.is_a?(NilObject) ? nil : seed.raw)
          IntegerObject.new(result)
        end

        def kernel_local_variables(context, _receiver)
          # local_variables is called from a kernel method frame; the caller's frame has the actual locals
          caller_frame = context.frames[-2] || context.frame
          names = caller_frame.local_names.map { |n| SymbolObject.from(n) }
          ArrayObject.new(names)
        end

        # BasicObject
        def basic_object___id__(_, v) = IntegerObject.new(v.__id__)

        def basic_object__equal_equal_(_, v1, v2) = bool_object_for(v1.equal?(v2))

        def basic_object_method_missing(context, receiver, name, args, kwargs)
          name_sym = name.is_a?(SymbolObject) ? name.raw : name
          receiver_desc = no_method_receiver_desc(receiver)
          violation = Fiber[:mm_visibility_violation]
          Fiber[:mm_visibility_violation] = nil
          exc = if violation && violation[1] == name_sym
                  vis_word = violation[0] == :private ? "private" : "protected"
                  class_name = violation[2]
                  e = FrozoneException.make(:NoMethodError, "#{vis_word} method '#{name_sym}' called for an instance of #{class_name}", name: name_sym, receiver: receiver)
                  e.vm_object.set_ivar(:@args, args.is_a?(ArrayObject) ? args : ArrayObject.new([]))
                  e
                elsif Fiber[:mm_implicit_self]
                  class_name = receiver.class_object.name
                  FrozoneException.make(:NameError, "undefined local variable or method '#{name_sym}' for an instance of #{class_name}", name: name_sym, receiver: receiver)
                else
                  e = FrozoneException.make(:NoMethodError, "undefined method '#{name_sym}' for #{receiver_desc}", name: name_sym, receiver: receiver)
                  e.vm_object.set_ivar(:@args, args.is_a?(ArrayObject) ? args : ArrayObject.new([]))
                  e
                end
          set_exc_backtrace(exc.vm_object, context)
          raise exc
        end

        def basic_object___send__(context, receiver, name, args, kwargs, block_arg = NilObject::NIL)
          method_name = send_method_name(name)
          raw_kwargs = kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k }
          block_obj = block_arg.is_a?(ProcObject) ? block_arg.block_object : block_arg
          block_obj = nil if block_obj.is_a?(NilObject)
          # Propagate caller's active refinements: send/public_send honor refinements
          # active at the call site (the frame that invoked send, which is our parent frame).
          frame = context.frame
          caller_refs = frame&.parent_frame&.active_refinements
          prev_refs = frame&.active_refinements
          frame&.active_refinements = caller_refs if caller_refs && !caller_refs.empty? && (prev_refs.nil? || prev_refs.empty?)
          begin
            receiver.dispatch(context, method_name, args.raw, raw_kwargs, block_obj, private_ok: true)
          ensure
            frame&.active_refinements = prev_refs
          end
        end

        def object_public_send(context, receiver, name, args, kwargs, block_arg = NilObject::NIL)
          method_name = send_method_name(name)
          raw_kwargs = kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k }
          block_obj = block_arg.is_a?(ProcObject) ? block_arg.block_object : block_arg
          block_obj = nil if block_obj.is_a?(NilObject)
          # Propagate caller's active refinements: send/public_send honor refinements
          # active at the call site (the frame that invoked send, which is our parent frame).
          frame = context.frame
          caller_refs = frame&.parent_frame&.active_refinements
          prev_refs = frame&.active_refinements
          frame&.active_refinements = caller_refs if caller_refs && !caller_refs.empty? && (prev_refs.nil? || prev_refs.empty?)
          begin
            receiver.dispatch(context, method_name, args.raw, raw_kwargs, block_obj, private_ok: false, public_only: true)
          ensure
            frame&.active_refinements = prev_refs
          end
        end

        # Kernel require/load
        def kernel_require(_, _receiver, path_obj)
          path = path_obj.raw
          loaded = GLOBALS[:"$LOADED_FEATURES"]
          loaded_paths = loaded.raw.map(&:raw)
          full_path = resolve_load_path(path)
          if full_path.nil?
            exc = FrozoneException.make(:LoadError, "cannot load such file -- #{path}")
            exc.vm_object.set_ivar(:@path, StringObject.new(path))
            raise exc
          end
          return FalseObject::FALSE if loaded_paths.include?(full_path)
          loaded.push(StringObject.new(full_path))
          begin
            Fiber[:vm_evaluate].call(full_path, raise_syntax_errors: true)
          rescue Ast::ReturnException
            # return at top level of required file stops loading gracefully
          rescue FrozoneException
            # Loading failed — remove from $LOADED_FEATURES so next require/autoload can retry
            loaded.raw.delete_if { |s| s.raw == full_path }
            raise
          end
          TrueObject::TRUE
        end

        def kernel_integer(context, _receiver, val, base, exception = NilObject::NIL)
          exc = exception.is_a?(NilObject) || exception.truthy?
          b = base.respond_to?(:raw) ? base.raw : 0
          if val.is_a?(IntegerObject)
            return val
          elsif val.is_a?(FloatObject)
            begin
              return IntegerObject.new(Integer(val.raw))
            rescue ::TypeError => e
              raise FrozoneException.make(:TypeError, e.message) if exc
              return NilObject::NIL
            end
          elsif val.is_a?(StringObject)
            begin
              return IntegerObject.new(Integer(val.raw, b))
            rescue ::ArgumentError => e
              raise FrozoneException.make(:ArgumentError, e.message) if exc
              return NilObject::NIL
            end
          elsif val.is_a?(NilObject)
            raise FrozoneException.make(:TypeError, "can't convert nil into Integer") if exc
            return NilObject::NIL
          else
            # Object with to_int or to_i
            begin
              if val.class_object.lookup_method(:to_int)
                return val.dispatch(context, :to_int, [], {})
              end
              return val.dispatch(context, :to_i, [], {})
            rescue FrozoneException
              raise if exc
              return NilObject::NIL
            end
          end
        end

        def kernel_float(_, _receiver, val) = FloatObject.new(val.is_a?(FloatObject) ? val.raw : Float(val.raw))

        def kernel_array(_, _receiver, val)
          return val if val.is_a?(ArrayObject)
          return NilObject::NIL.equal?(val) ? ArrayObject.new([]) : ArrayObject.new([val])
        end

        def kernel_dir(_, _receiver)
          stack = Fiber[:file_stack]
          return NilObject::NIL if stack.nil? || stack.empty?
          StringObject.new(File.dirname(stack.last))
        end

        def kernel_require_relative(_, _receiver, path_obj)
          rel = path_obj.raw
          stack = Fiber[:file_stack]
          raise "require_relative called outside of a file" if stack.nil? || stack.empty?
          full_path = File.expand_path(rel, File.dirname(stack.last))
          full_path += '.rb' unless full_path.end_with?('.rb')
          loaded = GLOBALS[:"$LOADED_FEATURES"]
          loaded_paths = loaded.raw.map(&:raw)
          return FalseObject::FALSE if loaded_paths.include?(full_path)
          loaded.push(StringObject.new(full_path))
          Fiber[:vm_evaluate].call(full_path, raise_syntax_errors: true)
          TrueObject::TRUE
        end

        def kernel_load(_, _receiver, path_obj, wrap_obj = NilObject::NIL)
          path = path_obj.raw
          full_path = File.exist?(path) ? path : resolve_load_path(path)
          if full_path.nil?
            exc = FrozoneException.make(:LoadError, "cannot load such file -- #{path}")
            exc.vm_object.set_ivar(:@path, StringObject.new(path))
            raise exc
          end
          wrap = wrap_obj && !wrap_obj.is_a?(NilObject) && !wrap_obj.is_a?(FalseObject)
          prev_wrap_mod = Fiber[:load_wrap_module]
          if wrap
            wrap_mod = ModuleObject.new(nil, nil)
            Fiber[:load_wrap_module] = wrap_mod
          end
          begin
            Fiber[:vm_evaluate].call(full_path, raise_syntax_errors: true)
          rescue Ast::ReturnException
            # return at top level of loaded file stops loading gracefully
          ensure
            Fiber[:load_wrap_module] = prev_wrap_mod if wrap
          end
          TrueObject::TRUE
        end

        def kernel_binding(context, _receiver)
          # Capture the calling frame (frames[-2] since we're inside a kernel method call).
          captured_frame = context.frames.length >= 2 ? context.frames[-2] : context.frame
          # Source location: where `binding` was called (context.call_site set by MethodCall.evaluate)
          binding_call_site = context.call_site || captured_frame&.incoming_call_site
          BindingObject.new(captured_frame, binding_call_site)
        end

        def kernel_eval(context, _receiver, code_obj, binding_arg = NilObject::NIL, filename_arg = NilObject::NIL, lineno_arg = NilObject::NIL)
          return NilObject::NIL unless code_obj.is_a?(StringObject)
          code = code_obj.raw
          eval_filename = filename_arg.is_a?(StringObject) ? filename_arg.raw : nil
          eval_lineno = lineno_arg.is_a?(IntegerObject) ? lineno_arg.raw : nil
          # If a BindingObject is passed, use its captured frame; otherwise use the caller's frame.
          binding_frame = if binding_arg.is_a?(BindingObject)
                            binding_arg.captured_frame
                          else
                            context.frames.length >= 2 ? context.frames[-2] : context.frame
                          end

          # Build closure chain: binding_frame + parent frames.
          # Used for reading/writing variables from enclosing block scopes.
          closure_chain = []
          walk = binding_frame
          while walk
            closure_chain << walk
            break if walk.parent_frame.nil?
            walk = walk.parent_frame
          end

          # When a BindingObject is given, use its authoritative name set (binding_local_names)
          # as outer_locals. This ensures per-binding isolation: vars only known to a specific
          # binding (not its dup/clone) won't be recognized as locals in other bindings' evals.
          # Without a BindingObject, fall back to the full closure chain locals.
          all_outer_locals = closure_chain.flat_map(&:local_names).uniq
          outer_locals = binding_arg.is_a?(BindingObject) ? binding_arg.binding_local_names : all_outer_locals
          code_enc = code.encoding != Encoding::UTF_8 ? code.encoding : nil
          # Ruby 3.4+: __FILE__ inside eval returns "(eval at file:line)" using the caller's location
          eval_filepath = eval_filename || (context.call_site ? "(eval at #{context.call_site})" : "(eval)")
          parser = Parser.new(code, outer_locals: outer_locals, encoding: code_enc, filepath: eval_filepath, line: eval_lineno)
          begin
            ast = parser.ast(raise_syntax_errors: true)
          rescue FrozoneException => e
            e.vm_object.set_ivar(:@path, StringObject.new(eval_filename)) if eval_filename
            raise
          end
          # Emit Prism warnings: always-level (e.g. integer_in_flip_flop) and verbose-level when $VERBOSE
          parser.prism_always_warnings.each { |msg| Frozone::Vm.emit_warning(context, msg) }
          if GLOBALS.fetch(:"$VERBOSE", FalseObject::FALSE).truthy?
            parser.prism_verbose_warnings.each { |msg| Frozone::Vm.emit_warning(context, msg) }
          end
          # Create eval frame using binding_frame's self/scopes (not the eval method frame),
          # so that `def`, `alias`, etc. use the correct lexical scope.
          new_frame = Frame.new(binding_frame.the_self, parser.top_level_locals, binding_frame.scopes)
          new_frame.block = binding_frame.block
          new_frame.parent_frame = binding_frame
          # Track which locals are eval-native (not from any outer scope).
          # BindingObject.collect_local_names uses own_locals to emit eval-native vars first.
          new_frame.own_locals = parser.top_level_locals.reject { |n| outer_locals.include?(n) }
          # Inherit def_scope and method_frame from binding so `def` targets the right class.
          # If the binding frame has no def_scope AND its self is not a class/module (e.g. a
          # lambda frame), walk up parent frames to find the nearest closure def context (e.g.
          # instance_eval block or method frame). Skip this walk when the binding frame's self
          # is already a class/module — in that case, method_def.rb uses the_self directly.
          inherited_def_scope = binding_frame.def_scope
          if !inherited_def_scope && !binding_frame.the_self.is_a?(ModuleObject)
            walk = binding_frame.parent_frame
            while walk && !inherited_def_scope
              inherited_def_scope = walk.def_scope
              walk = walk.parent_frame
            end
          end
          new_frame.def_scope = inherited_def_scope
          new_frame.method_frame = binding_frame.method_frame
          # Inherit current_method so that __method__ inside eval returns the binding's method.
          # Walk up parent_frame to skip transparent dispatch methods (__send__, send, public_send).
          transparent = %i[__send__ send public_send]
          binding_method_frame = binding_frame
          while binding_method_frame
            m = binding_method_frame.current_method
            break if m && !transparent.include?(m.name)
            binding_method_frame = binding_method_frame.parent_frame
          end
          new_frame.current_method = binding_method_frame&.current_method
          # Copy locals from full closure chain into eval frame (innermost frame wins).
          # This lets eval read outer-scope variables even if not in binding_frame.local_names.
          closure_chain.reverse_each do |f|
            f.local_names.each { |name| new_frame.set_local(name, f.get_local(name)) if new_frame.local_names.include?(name) }
          end
          # Save and restore current_visibility of the enclosing module to prevent
          # visibility toggles inside `eval` from leaking outside it.
          # Use binding_frame.the_self when it's a module (e.g. Module.new { eval "private" }),
          # otherwise fall back to the runtime scope stack.
          the_self = binding_frame.the_self
          current_mod = if the_self.is_a?(ModuleObject)
                          the_self
                        else
                          context.scopes.last || binding_frame.scopes.last
                        end
          current_mod = nil unless current_mod.is_a?(ModuleObject)
          prev_vis = current_mod&.current_visibility
          context.push_frame(new_frame)
          begin
            result = ast.evaluate(context)
            # Write back locals to the appropriate frame in the closure chain.
            # Existing vars update their original frame (shared between all bindings of that frame).
            # New eval vars go to binding_frame AND are added to binding_arg's name set only.
            new_frame.local_names.each do |name|
              target = closure_chain.find { |f| f.local_names.include?(name) }
              if target
                target.set_local(name, new_frame.get_local(name))
              else
                binding_frame.set_local(name, new_frame.get_local(name))
                binding_arg.binding_local_names |= [name] if binding_arg.is_a?(BindingObject)
              end
            end
            result
          rescue Ast::RetryException, Ast::RedoException
            raise FrozoneException.make(:SyntaxError, "Invalid #{$!.class.name.split('::').last.sub('Exception', '').downcase} in eval")
          rescue Ast::BreakException, Ast::NextException
            raise FrozoneException.make(:LocalJumpError, "unexpected #{$!.class.name.split('::').last.sub('Exception', '').downcase}")
          ensure
            context.pop_frame
            current_mod.current_visibility = prev_vis if current_mod && prev_vis
          end
        end

        def env_get(_, key) = (v = ENV[key.raw]) ? StringObject.new(v) : NilObject::NIL
        def env_set(_, key, val) = (ENV[key.raw] = val.is_a?(NilObject) ? nil : val.raw; val)
        def env_delete(_, key) = (v = ENV.delete(key.raw)) ? StringObject.new(v) : NilObject::NIL
        def env_key?(_, key) = bool_object_for(ENV.key?(key.raw))
        def env_keys(_) = ArrayObject.new(ENV.keys.map { |k| StringObject.new(k) })
        def env_values(_) = ArrayObject.new(ENV.values.map { |v| StringObject.new(v) })
        def env_size(_) = IntegerObject.new(ENV.size)
        def env_clear(_) = (ENV.clear; NilObject::NIL)
        def env_pairs(_) = ArrayObject.new(ENV.map { |k, v| ArrayObject.new([StringObject.new(k), StringObject.new(v)]) })
        def env_to_hash(_) = HashObject.new(ENV.to_h { |k, v| [StringObject.new(k), StringObject.new(v)] })

        private

        # Bare `raise` with no args: re-raise the current exception, or raise RuntimeError("").
        def reraise_current_or_runtime(cause, context)
          if cause
            set_exc_backtrace(cause, context) unless cause.get_ivar(:@backtrace).is_a?(ArrayObject)
            raise FrozoneException.new(cause, cause.get_ivar(:@message)&.raw || "")
          end
          exc = FrozoneException.make(:RuntimeError, "")
          set_exc_backtrace(exc.vm_object, context)
          raise exc
        end

        # `raise SomeClass[, "message"]` — call SomeClass.exception(message) to build instance.
        def raise_from_exception_class(context, klass, message_arg, backtrace_arg, cause)
          exc_obj = if message_arg && !message_arg.is_a?(NilObject)
                      klass.dispatch(context, :exception, [message_arg], {})
                    else
                      klass.dispatch(context, :exception, [], {})
                    end
          msg_str = begin
            exc_obj.dispatch(context, :message, [], {}).raw
          rescue StandardError
            klass.name.to_s
          end
          effective_cause = (cause && !cause.equal?(exc_obj)) ? cause : nil
          validate_cause(effective_cause, exc_obj)
          exc_obj.set_ivar(:@cause, effective_cause) if effective_cause
          apply_backtrace(exc_obj, backtrace_arg, context)
          raise FrozoneException.new(exc_obj, msg_str)
        end

        # `raise "message"` — create RuntimeError with string.
        def raise_from_string(context, msg, backtrace_arg, cause)
          exc = FrozoneException.make(:RuntimeError, msg.raw)
          effective_cause = (cause && !cause.equal?(exc.vm_object)) ? cause : nil
          exc.vm_object.set_ivar(:@cause, effective_cause) if effective_cause
          apply_backtrace(exc.vm_object, backtrace_arg, context)
          raise exc
        end

        # `raise exception_object` — use the #exception protocol.
        def raise_from_exception_protocol(context, msg, message_arg, backtrace_arg, cause)
          has_message_arg = !message_arg.is_a?(NilObject)
          exc_obj = begin
            msg.dispatch(context, :exception, has_message_arg ? [message_arg] : [], {})
          rescue FrozoneException => _e
            # NoMethodError or similar — try using msg directly if it's Exception subclass
            exception_instance?(msg) ? msg : (raise FrozoneException.make(:TypeError, "exception class/object expected"))
          rescue
            raise FrozoneException.make(:TypeError, "exception class/object expected")
          end
          # Verify the result is an exception instance
          if exc_obj.is_a?(ObjectObject)
            raise FrozoneException.make(:TypeError, "exception object expected") unless exception_instance?(exc_obj)
          elsif !exc_obj.is_a?(FrozoneException)
            raise FrozoneException.make(:TypeError, "exception object expected")
          end
          msg_str = begin
            exc_obj.dispatch(context, :message, [], {})
          rescue
            nil
          end
          msg_str = msg_str.is_a?(StringObject) ? msg_str.raw : "exception"
          effective_cause = (cause && !cause.equal?(exc_obj)) ? cause : nil
          validate_cause(effective_cause, exc_obj)
          exc_obj.set_ivar(:@cause, effective_cause) if effective_cause && exc_obj.is_a?(ObjectObject)
          # Only set backtrace if explicitly provided or exception has no backtrace yet
          apply_backtrace(exc_obj, backtrace_arg, context) unless exc_obj.is_a?(ObjectObject) && exc_obj.get_ivar(:@backtrace).is_a?(ArrayObject)
          raise FrozoneException.new(exc_obj, msg_str)
        end
      end
    end
  end
end
