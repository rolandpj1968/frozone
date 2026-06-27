# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        def emit_vm_warning(context, msg) = Frozone::Vm.emit_warning(context, msg)
        def kernel_rand(context, _receiver, n) = random_rand(context, nil, n)
        def signal_trap(_, _signal, _block_arg = FNIL) = FNIL

        def signal_register(context, signal_name, handler)
          name = fstr?(signal_name) ? signal_name.raw : signal_name.raw.to_s
          if fnil?(handler)
            Signal.trap(name, "IGNORE")
          elsif handler.is_a?(::String)
            Signal.trap(name, handler)
          elsif handler.respond_to?(:raw) && handler.raw.is_a?(::String)
            Signal.trap(name, handler.raw)
          else
            callable = handler
            Signal.trap(name) do |signo|
              ctx = Fiber[:context] || context
              signo_obj = n2f_int(signo)
              if callable.respond_to?(:invoke)
                callable.invoke(ctx, [signo_obj])
              else
                callable.dispatch(ctx, :call, [signo_obj], {})
              end
            end
          end
          FNIL
        end
        def basic_object___id__(_, v) = n2f_int(v.__id__)
        def basic_object__equal_equal_(_, v1, v2) = n2f_bool(v1.equal?(v2))
        def kernel_float(_, _receiver, val) = n2f_float(ffloat?(val) ? val.raw : Float(val.raw))

        def file_realpath_cached(_, path_str)
          expanded = fstr?(path_str) ? path_str.raw : path_str.to_s
          real = Frozone::Vm::Vm::FILE_REALPATH_CACHE[expanded]
          real ? n2f_str(real, frozen: true) : FNIL
        end

        # Bespoke raw-write to host stderr. Bypasses dispatch chains —
        # use when the regular puts path is broken. Mirrors the box-first
        # HPP intrinsic so the same Ruby call works in both modes.
        # 2-arg signature (no context): we're called from host vm.rb as a
        # normal Ruby method, not through Ast::IntrinsicCall.evaluate.
        # The matching HPP intrinsic is intrinsic_dbg_write(self_, s).
        # Accepts either a Frozone Vm::StringObject (host MRI value) or a
        # plain String literal (which is how vm.rb's calls compile).
        def dbg_write(_receiver, s)
          raw = fstr?(s) ? s.raw : s.to_s
          $stderr.write(raw)
          $stderr.write("\n")
          $stderr.flush
          FNIL
        end

        # Raw fwrite to stdout/stderr — bypass the IOObject dispatch
        # chain. Box-first compiled `io_write` (in io_intrinsics.rb)
        # routes here when receiver.native_io is nil (bootstrap state:
        # GLOBALS["$stdout"] is set to IOObject.new(nil, ..., stream_tag:
        # :stdout) before MRI's $stdout is reachable from the compiled
        # binary). The matching HPP intrinsics are
        # intrinsic_io_raw_write_stdout / _stderr in intrinsics.hpp.
        # Returns the byte count as a Frozone Integer.
        def io_raw_write_stdout(_receiver, s)
          raw = fstr?(s) ? s.raw : s.to_s
          $stdout.write(raw)
          n2f_int(raw.bytesize)
        end

        def io_raw_write_stderr(_receiver, s)
          raw = fstr?(s) ? s.raw : s.to_s
          $stderr.write(raw)
          n2f_int(raw.bytesize)
        end

        def kernel_puts(context, _receiver, args)
          stdout_vm = GLOBALS[:"$stdout"]
          if frozone_stdout_replaced?(stdout_vm)
            stdout_vm.dispatch(context, :puts, args.raw, {})
          elsif args.raw.empty?
            $stdout.puts
          else
            args.raw.each { |a| $stdout.puts(a.dispatch(context, :to_s, [], {}).raw) }
          end
          FNIL
        end

        def kernel_print(context, _receiver, args)
          stdout_vm = GLOBALS[:"$stdout"]
          if frozone_stdout_replaced?(stdout_vm)
            if args.raw.empty?
              dollar_under = GLOBALS[:"$_"] || FNIL
              stdout_vm.dispatch(context, :print, [dollar_under], {}) unless fnil?(dollar_under)
            else
              stdout_vm.dispatch(context, :print, args.raw, {})
            end
          elsif args.raw.empty?
            dollar_under = GLOBALS[:"$_"] || FNIL
            $stdout.print(dollar_under.dispatch(context, :to_s, [], {}).raw) unless fnil?(dollar_under)
          else
            args.raw.each { |a| $stdout.print(a.dispatch(context, :to_s, [], {}).raw) }
          end
          FNIL
        end

        def kernel_warn(context, _receiver, args)
          stderr_vm = GLOBALS[:"$stderr"]
          strs = args.raw.map { |a| a.dispatch(context, :to_s, [], {}) }
          if strs.empty?
            stderr_vm.dispatch(context, :puts, [], {})
          else
            stderr_vm.dispatch(context, :puts, strs, {})
          end
          FNIL
        end

        # Emit a verbose-only warning (e.g. "given block not used") with the caller's call-site.
        # Uses the incoming_call_site of the current frame (where the Ruby method was called from).
        # Output format: "file:line: warning: msg"
        def kernel_verbose_warn(context, _receiver, msg_obj)
          verbose = GLOBALS.fetch(:"$VERBOSE", FFALSE).truthy?
          return FNIL unless verbose
          msg = fstr?(msg_obj) ? msg_obj.raw : msg_obj.dispatch(context, :to_s, [], {}).raw
          location = context.frame&.incoming_call_site
          Frozone::Vm.emit_warning(context, msg, location: location)
          FNIL
        end

        # Emit an unconditional warning with the caller's call-site (for deprecation warnings).
        # Output format: "file:line: warning: msg"
        def kernel_deprecation_warn(context, _receiver, msg_obj)
          msg = fstr?(msg_obj) ? msg_obj.raw : msg_obj.dispatch(context, :to_s, [], {}).raw
          location = context.frame&.incoming_call_site
          Frozone::Vm.emit_warning(context, msg, location: location)
          FNIL
        end

        def kernel_raise(context, _receiver, msg = FNIL, message_arg = FNIL, backtrace_arg = FNIL, cause_arg = FNIL)
          current_exc = GLOBALS[:"$!"]
          no_cause_sentinel = fsym?(cause_arg) && cause_arg.raw == :__raise_no_cause__
          cause_was_given = !no_cause_sentinel  # true if cause: was explicitly passed (even as nil)
          explicit_cause = cause_was_given && !fnil?(cause_arg)

          # Distinguish bare `raise` (no args → :__raise_no_arg__ sentinel) from `raise(nil)` (explicit nil → TypeError)
          no_arg_sentinel = fsym?(msg) && msg.raw == :__raise_no_arg__

          # ArgumentError: only cause: given (even nil) with no positional args
          raise FrozoneException.make(:ArgumentError, "only cause is given with no arguments") if no_arg_sentinel && cause_was_given

          # Validate explicit cause type before building exception
          if explicit_cause
            raise FrozoneException.make(:TypeError, "exception object expected") unless exception_instance?(cause_arg)
          end

          cause = if no_cause_sentinel
                    (current_exc && !fnil?(current_exc)) ? current_exc : nil
                  elsif fnil?(cause_arg)
                    nil
                  else
                    cause_arg
                  end

          if no_arg_sentinel
            reraise_current_or_runtime(cause, context)
          elsif msg.is_a?(ClassObject) || msg.is_a?(ModuleObject)
            raise_from_exception_class(context, msg, message_arg, backtrace_arg, cause, auto_cause: no_cause_sentinel)
          elsif fstr?(msg) && fnil?(message_arg)
            raise_from_string(context, msg, backtrace_arg, cause, auto_cause: no_cause_sentinel)
          else
            raise_from_exception_protocol(context, msg, message_arg, backtrace_arg, cause, auto_cause: no_cause_sentinel)
          end
        end

        def caller_slice(entries, start_obj, length_obj)
          if start_obj.is_a?(RangeObject)
            r_begin = fnil?(start_obj.begin_val) ? 0 : start_obj.begin_val.raw
            r_end = fnil?(start_obj.end_val)   ? nil : start_obj.end_val.raw
            mri_range = r_end.nil? ? (r_begin..) : (start_obj.exclusive? ? (r_begin...r_end) : (r_begin..r_end))
            entries[mri_range]
          else
            start = fint?(start_obj)  ? start_obj.raw : 1
            length = fint?(length_obj) ? length_obj.raw : nil
            length ? entries[start, length] : entries[start..]
          end
        end

        # Build a Thread#backtrace_locations-compatible location array.
        # The first entry shows WHERE backtrace_locations was called, labeled as
        # 'Thread#backtrace_locations' — matching MRI's native method frame semantics.
        def thread_backtrace_locations(context, _receiver, start_obj = FNIL, length_obj = FNIL)
          all_frames = context.frames.reverse
          # Find the backtrace_locations frame so we can get its call site and label.
          bt_idx = all_frames.rindex { |f| f.current_method&.name == :backtrace_locations }
          return n2f_arr([]) unless bt_idx

          bt_frame = all_frames[bt_idx]
          bt_label = caller_method_name(bt_frame.current_method, bt_frame.the_self, false)
          bt_call_site = bt_frame.incoming_call_site

          # Build entries for frames above backtrace_locations (the user's call stack).
          # These use the same [call_site, label] convention as collect_caller_frames.
          user_frames = all_frames[(bt_idx + 1)..]
          entries_raw = []
          i = 0
          while i < user_frames.length - 1
            call_site = user_frames[i].incoming_call_site || "unknown:0"
            immediate_outer = user_frames[i + 1]
            if proc_call_frame?(immediate_outer) || lambda_body_frame?(immediate_outer)
              outer, lambda_depth = find_lambda_outer_frame(user_frames, i + 1)
              effective_method = outer.current_method || outer.method_frame&.current_method
              meth = caller_method_name(effective_method, outer.the_self, outer.current_method.nil?)
              if lambda_depth > 0 && meth && !meth.start_with?("<")
                meth = lambda_depth == 1 ? "block in #{meth}" : "block (#{lambda_depth} levels) in #{meth}"
              end
            elsif regular_block_frame?(immediate_outer)
              outer = immediate_outer
              enclosing_mf = outer.method_frame
              depth = block_nesting_depth(user_frames, i + 1, enclosing_mf)
              effective_method = enclosing_mf&.current_method
              meth = caller_method_name(effective_method, outer.the_self, false)
              if depth > 0 && meth && !meth.start_with?("<")
                meth = depth == 1 ? "block in #{meth}" : "block (#{depth} levels) in #{meth}"
              end
            else
              outer = immediate_outer
              effective_method = outer.current_method || outer.method_frame&.current_method
              in_block = outer.current_method.nil?
              meth = caller_method_name(effective_method, outer.the_self, in_block)
            end
            entries_raw << [call_site, meth]
            i += 1
          end

          # Prepend the backtrace_locations entry itself: call site WHERE it was called,
          # labeled with 'Thread#backtrace_locations' (MRI native method frame semantics).
          first_entry = bt_call_site ? [bt_call_site, bt_label] : nil
          all_raw = first_entry ? [first_entry] + entries_raw : entries_raw

          location_class = Core::OBJECT_CLASS.get_constant(:Thread)&.get_constant(:Backtrace)&.get_constant(:Location)
          entries = all_raw.map do |call_site, meth|
            str_obj = n2f_str("#{call_site}:in '#{meth}'", frozen: true)
            location_class ? location_class.dispatch(context, :_from_string, [str_obj], {}, nil, private_ok: true) : str_obj
          end

          sliced = caller_slice(entries, start_obj, length_obj)
          sliced ? n2f_arr(sliced) : FNIL
        end

        def kernel_caller_locations(context, _receiver, start_obj = FNIL, length_obj = FNIL)
          frames = collect_caller_frames(context, :caller_locations)

          location_class = Core::OBJECT_CLASS.get_constant(:Thread)&.get_constant(:Backtrace)&.get_constant(:Location)
          entries = frames.map do |call_site, meth|
            str_obj = n2f_str("#{call_site}:in '#{meth}'", frozen: true)
            if location_class
              location_class.dispatch(context, :_from_string, [str_obj], {}, nil, private_ok: true)
            else
              str_obj
            end
          end

          sliced = caller_slice(entries, start_obj, length_obj)
          sliced ? n2f_arr(sliced) : FNIL
        end

        # Build the Ruby caller() array from the current frame stack.
        # `start` — how many logical entries to skip (0 = include the frame that called caller)
        # `length` — max entries to return (nil = all)
        def kernel_caller(context, _receiver, start_obj = FNIL, length_obj = FNIL)
          frames = collect_caller_frames(context, :caller)

          entries = frames.map do |call_site, meth|
            n2f_str("#{call_site}:in '#{meth}'", frozen: true)
          end

          # Apply start offset and length
          sliced = caller_slice(entries, start_obj, length_obj)
          sliced ? n2f_arr(sliced) : FNIL
        end

        def kernel_p(context, _receiver, args)
          stdout_vm = GLOBALS[:"$stdout"]
          if frozone_stdout_replaced?(stdout_vm)
            inspected = args.raw.map { |a| a.dispatch(context, :inspect, [], {}) }
            inspected.each { |s| stdout_vm.dispatch(context, :puts, [s], {}) }
            stdout_vm.dispatch(context, :flush, [], {})
          else
            args.raw.each { |a| $stdout.puts(a.dispatch(context, :inspect, [], {}).raw) }
            $stdout.flush
          end
          args.raw.length == 1 ? args.raw.first : args
        end

        # Returns true if Frozone's $stdout has been replaced with something
        # other than the initial MRI stdout (e.g. a file, IOStub, or mock in specs).
        def frozone_stdout_replaced?(stdout_vm)
          return false if stdout_vm.nil?
          return true unless fio?(stdout_vm)  # non-IO Frozone object (e.g. IOStub) = replaced
          !stdout_vm.native_io.equal?(STDOUT) # IO not wrapping original STDOUT = replaced
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
            return FNIL unless mf
            m = mf.current_method
            return FNIL unless m
            callee = mf.callee_name
            unless callee && SEND_TRANSPARENT_CALLEE_NAMES.include?(callee)
              return n2f_sym(m.name)
            end
            i -= 1
          end
          FNIL
        end

        def kernel__callee__(context, _receiver)
          # __callee__ returns the callee name of the innermost non-transparent method frame.
          # send/__send__/public_send are transparent: skip them and look at the calling method.
          frames = context.frames
          i = frames.length - 2
          while i >= 0
            mf = frames[i].method_frame
            return FNIL unless mf
            cn = mf.callee_name
            break unless cn && SEND_TRANSPARENT_CALLEE_NAMES.include?(cn)
            i -= 1
          end
          return FNIL if i < 0
          mf = frames[i].method_frame
          return FNIL unless mf
          cn = mf.callee_name
          cn ? n2f_sym(cn) : FNIL
        end

        SEND_METHOD_NAMES = %i[send __send__ public_send].freeze

        def kernel_block_given(context, _receiver)
          # block_given? is a Ruby method call (adds one frame), so start one below current.
          # Skip send/__send__/public_send frames — they're transparent for block_given? purposes.
          frames = context.frames
          idx = frames.length - 2
          while idx >= 0 && SEND_METHOD_NAMES.include?(frames[idx].current_method&.name)
            idx -= 1
          end
          caller_frame = idx >= 0 ? frames[idx] : nil
          # define_method bodies always see block_given? == false (Ruby semantics), even inside
          # nested blocks (which inherit the define_method frame as their method_frame).
          return FFALSE if caller_frame&.method_frame&.current_method.is_a?(DefinedMethod)
          b = caller_frame&.block
          n2f_bool(!b.nil? && !fnil?(b))
        end

        def kernel_catch(context, _receiver, tag, block)
          tag_raw = fnil?(tag) ? :__catch_nil__ : tag.respond_to?(:raw) ? tag.raw : tag
          return FNIL if fnil?(block)
          result = catch(tag_raw) { block.invoke(context, [tag]) }
          result.is_a?(ObjectObject) ? result : FNIL
        end

        def kernel_throw(_, _receiver, tag, value = FNIL)
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
          cmd = cmd_obj.raw
          # Force binary to avoid ArgumentError on invalid UTF-8 bytes in command
          cmd_binary = cmd.b
          result = `#{cmd_binary}`
          GLOBALS[:"$?"] = ProcessStatusObject.from_native($?)
          enc = result.encoding
          filtered = result.lines.reject { |l|
            begin; BUNDLER_NOISE_RE.match?(l); rescue ::ArgumentError; false; end
          }.join
          n2f_str(filtered)
        end

        def kernel_system(context, _receiver, *args)
          argv = args.map { |a|
            if fstr?(a)
              a.raw
            elsif a.is_a?(ArrayObject)
              a.raw.map { |s| fstr?(s) ? s.raw : s.raw.to_s }
            elsif a.is_a?(HashObject)
              {}.tap do |h|
                a.raw.each { |k, v|
                  hk = k.is_a?(SymbolObject) ? k.raw : k.to_s
                  hv = case v
                       when FNIL then nil
                       when FFALSE then false
                       when FTRUE then true
                       else v.respond_to?(:raw) ? v.raw : v
                       end
                  h[hk] = hv
                }
              end
            else
              a.raw.to_s
            end
          }
          reraise(::Errno::ENOENT, ::RuntimeError) do
            result = ::Kernel.system(*argv)
            GLOBALS[:"$?"] = ProcessStatusObject.from_native($?) if $?
            result ? FTRUE : (result.nil? ? FNIL : FFALSE)
          end
        end

        def kernel_spawn(_, _receiver, *args)
          argv = args.map { |a|
            if fstr?(a)
              a.raw
            elsif a.is_a?(ArrayObject)
              a.raw.map { |s| fstr?(s) ? s.raw : s.raw.to_s }
            elsif a.is_a?(HashObject)
              {}.tap do |h|
                a.raw.each { |k, v|
                  hk = k.is_a?(SymbolObject) ? k.raw : k.to_s
                  hv = case v
                       when FNIL then nil
                       when FFALSE then false
                       when FTRUE then true
                       else v.respond_to?(:raw) ? v.raw : v
                       end
                  h[hk] = hv
                }
              end
            else
              a.raw.to_s
            end
          }
          n2f_int(::Kernel.spawn(*argv))
        end

        # `os_waitpid(pid, flags)` — thin POSIX bridge. Returns
        # [child_pid, raw_status] Array or nil (WNOHANG / ECHILD).
        # Process.wait/wait2/waitall in lib/core/4.0/process.rb construct
        # Process::Status on top.
        def os_waitpid(_, pid_obj, flags_obj)
          pid = fint?(pid_obj) ? pid_obj.raw : -1
          flags = fint?(flags_obj) ? flags_obj.raw : 0
          begin
            result_pid = ::Process.waitpid(pid, flags)
          rescue ::Errno::ECHILD
            return FNIL
          end
          return FNIL if result_pid.nil?
          raw = $?.to_i
          n2f_arr([n2f_int(result_pid), n2f_int(raw)])
        end

        def process_wait(_, _receiver, pid_obj = FNIL, flags_obj = FNIL)
          pid = fint?(pid_obj)   ? pid_obj.raw   : -1
          flags = fint?(flags_obj) ? flags_obj.raw :  0
          reraise(::Errno::ECHILD) do
            result_pid = ::Process.wait(pid, flags)
            GLOBALS[:"$?"] = ProcessStatusObject.from_native($?) if $?
            n2f_int(result_pid)
          end
        end

        def process_wait2(_, _receiver, pid_obj = FNIL, flags_obj = FNIL)
          pid = fint?(pid_obj)   ? pid_obj.raw   : -1
          flags = fint?(flags_obj) ? flags_obj.raw :  0
          reraise(::Errno::ECHILD) do
            result_pid, status = ::Process.wait2(pid, flags)
            GLOBALS[:"$?"] = ProcessStatusObject.from_native(status) if status
            n2f_arr([n2f_int(result_pid), ProcessStatusObject.from_native(status)])
          end
        end

        def process_waitall(_, _receiver = FNIL)
          results = ::Process.waitall
          n2f_arr(results.map { |pid, st|
            GLOBALS[:"$?"] = ProcessStatusObject.from_native(st) if st
            n2f_arr([n2f_int(pid), ProcessStatusObject.from_native(st)])
          })
        end

        def kernel_exec(_, _receiver, *args)
          argv = args.map { |a|
            if fstr?(a)
              a.raw
            elsif a.is_a?(ArrayObject)
              a.raw.map { |s| fstr?(s) ? s.raw : s.raw.to_s }
            elsif a.is_a?(HashObject)
              {}.tap do |h|
                a.raw.each { |k, v|
                  hk = k.is_a?(::String) ? k : k.to_s
                  hv = v.nil? ? nil : (v.is_a?(::String) ? v : v.to_s)
                  h[hk] = hv
                }
              end
            else
              a.raw.to_s
            end
          }
          ::Kernel.exec(*argv)
        end

        def kernel_global_variables(_, _receiver)
          keys = GLOBALS.keys.map { |k| n2f_sym(k) }
          ArrayObject.new(keys)
        end

        def kernel_abort(context, _receiver, msg)
          str_msg = nil
          unless fnil?(msg)
            if fstr?(msg)
              str_msg = msg
            else
              begin
                result = msg.dispatch(context, :to_str, [], {})
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{msg.class_object.name} into String") unless fstr?(result)
                str_msg = result
              rescue FrozoneException => e
                # Re-raise non-NoMethodError Frozone exceptions; convert NoMethodError to TypeError
                raise unless e.frozone_class_name == :NoMethodError
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{msg.class_object.name} into String")
              end
            end
            stderr = GLOBALS[:"$stderr"]
            stderr.dispatch(context, :puts, [str_msg], {}) rescue nil
          end
          exc_class = Core::OBJECT_CLASS.get_constant(:SystemExit)
          exc_obj = ObjectObject.new(exc_class)
          exc_obj.set_ivar(:@status, n2f_int(1))
          exc_obj.set_ivar(:@message, str_msg || n2f_str(""))
          raise FrozoneException.new(exc_obj, "exit")
        end

        def kernel_exit(_, _receiver, code)
          status = ftrue?(code) ? 0 : ffalse?(code) ? 1 : fint?(code) ? code.raw : 0
          exc_class = Core::OBJECT_CLASS.get_constant(:SystemExit)
          exc_obj = ObjectObject.new(exc_class)
          exc_obj.set_ivar(:@status, n2f_int(status))
          exc_obj.set_ivar(:@message, n2f_str("exit"))
          raise FrozoneException.new(exc_obj, "exit")
        end

        def kernel_srand(_, _receiver, seed)
          raw = f2n_raw(seed)
          result = raw.nil? ? srand : srand(raw)
          n2f_int(result)
        end

        def kernel_local_variables(context, _receiver)
          # local_variables is called from a kernel method frame; the caller's frame has the actual locals
          caller_frame = context.frames[-2] || context.frame
          names = caller_frame.local_names.map { |n| n2f_sym(n) }
          n2f_arr(names)
        end

        def basic_object_method_missing(context, receiver, name, args, kwargs)
          name_sym = fsym?(name) ? name.raw : name
          receiver_desc = no_method_receiver_desc(receiver)
          violation = Fiber[:mm_visibility_violation]
          Fiber[:mm_visibility_violation] = nil
          exc = if violation && violation[1] == name_sym
                  vis_word = violation[0] == :private ? "private" : "protected"
                  class_name = violation[2]
                  e = FrozoneException.make(:NoMethodError, "#{vis_word} method '#{name_sym}' called for an instance of #{class_name}", name: name_sym, receiver: receiver)
                  e.vm_object.set_ivar(:@args, farray?(args) ? args : n2f_arr([]))
                  e
                elsif Fiber[:mm_implicit_self]
                  class_name = receiver.class_object.name
                  FrozoneException.make(:NameError, "undefined local variable or method '#{name_sym}' for an instance of #{class_name}", name: name_sym, receiver: receiver)
                else
                  e = FrozoneException.make(:NoMethodError, "undefined method '#{name_sym}' for #{receiver_desc}", name: name_sym, receiver: receiver)
                  e.vm_object.set_ivar(:@args, farray?(args) ? args : n2f_arr([]))
                  e
                end
          set_exc_backtrace(exc.vm_object, context)
          apply_auto_cause(exc.vm_object)
          raise exc
        end

        def basic_object___send__(context, receiver, name, args, kwargs, block_arg = FNIL)
          method_name = send_method_name(name)
          raw_kwargs = kwargs.raw.transform_keys { |k| fsym?(k) ? k.raw : k }
          block_obj = block_arg.is_a?(ProcObject) ? block_arg.block_object : block_arg
          block_obj = nil if fnil?(block_obj)
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

        def object_public_send(context, receiver, name, args, kwargs, block_arg = FNIL)
          method_name = send_method_name(name)
          raw_kwargs = kwargs.raw.transform_keys { |k| fsym?(k) ? k.raw : k }
          block_obj = block_arg.is_a?(ProcObject) ? block_arg.block_object : block_arg
          block_obj = nil if fnil?(block_obj)
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
          loaded_paths = loaded.raw.map { |s| s.respond_to?(:raw) ? s.raw : s.to_s }
          path_rb = load_add_rb(path)

          # Check exact input strings first (handles non-canonical paths stored as-is)
          return FFALSE if loaded_paths.include?(path_rb)

          is_explicit = path.start_with?('/') || path.start_with?('./') || path.start_with?('../') || path.start_with?('~')
          unless is_explicit
            # For bare/relative paths: check all $LOAD_PATH candidates against $LOADED_FEATURES
            # This handles "don't load feature twice when $LOAD_PATH is modified"
            candidates = load_path_candidates(path_rb)
            return FFALSE if candidates.any? { |c| loaded_paths.include?(c) }
          end

          full_path = begin
            resolve_load_path(path)
          rescue ::Errno::EACCES => e
            raise FrozoneException.make(:LoadError, e.message)
          end
          if full_path.nil?
            # If the non-extensioned path (no .rb) is in $LOADED_FEATURES, return false instead of LoadError
            return FFALSE if path != path_rb && loaded_paths.include?(path)
            # Check if a C extension exists at this path (no .rb, but .so/.bundle/.dylib).
            # MRI raises LoadError with path=nil when the file exists but loading fails
            # (as opposed to a missing file where path is set).
            native_ext_exists = !path.end_with?('.rb') && %w[.so .bundle .dylib .dll].any? do |ext|
              ::File.exist?(path.end_with?(ext) ? path : "#{path}#{ext}")
            end
            exc = FrozoneException.make(:LoadError, "cannot load such file -- #{path}")
            exc.vm_object.set_ivar(:@path, native_ext_exists ? FNIL : n2f_str(path))
            raise exc
          end
          # Check for circular require before general "already loaded" check
          currently_loading = (Fiber[:currently_loading_files] ||= ::Set.new)
          if loaded_paths.include?(full_path) && currently_loading.include?(full_path)
            Frozone::Vm.emit_warning(_, "loading in progress, circular require considered harmful - #{full_path}")
            return FFALSE
          end
          return FFALSE if loaded_paths.include?(full_path)
          # Guard against recursive require: add to $LOADED_FEATURES before loading
          loaded.raw.push(n2f_str(full_path))
          currently_loading.add(full_path)
          begin
            Fiber[:vm_evaluate].call(full_path, raise_syntax_errors: true)
          rescue Ast::ReturnException
            # return at top level of required file stops loading gracefully
          rescue ::Errno::EACCES => e
            loaded.raw.delete_if { |s| s.respond_to?(:raw) && s.raw == full_path }
            raise FrozoneException.make(:LoadError, e.message)
          rescue FrozoneException
            # Loading failed — remove from $LOADED_FEATURES so next require/autoload can retry
            loaded.raw.delete_if { |s| s.respond_to?(:raw) && s.raw == full_path }
            raise
          ensure
            currently_loading.delete(full_path)
          end
          FTRUE
        end

        def kernel_integer(context, _receiver, val, base, exception = FNIL)
          exc = fnil?(exception) || exception.truthy?
          b = fobj?(base) ? base.raw : 0
          if fint?(val)
            return val
          elsif ffloat?(val)
            begin
              return n2f_int(Integer(val.raw))
            rescue ::TypeError => e
              raise FrozoneException.make(:TypeError, e.message) if exc
              return FNIL
            end
          elsif fstr?(val)
            begin
              return n2f_int(Integer(val.raw, b))
            rescue ::ArgumentError => e
              raise FrozoneException.make(:ArgumentError, e.message) if exc
              return FNIL
            end
          elsif fnil?(val)
            raise FrozoneException.make(:TypeError, "can't convert nil into Integer") if exc
            return FNIL
          else
            # Object with to_int or to_i
            begin
              if val.class_object.lookup_method(:to_int)
                return val.dispatch(context, :to_int, [], {})
              end
              return val.dispatch(context, :to_i, [], {})
            rescue FrozoneException
              raise if exc
              return FNIL
            end
          end
        end

        def kernel_rational_from_string(context, _receiver, str_obj, exception_obj)
          exc = exception_obj.truthy?
          r = begin
            ::Kernel.Rational(str_obj.raw, exception: exc)
          rescue ::ArgumentError => e
            raise FrozoneException.make(:ArgumentError, e.message)
          end
          return FNIL if r.nil?
          rat_class = Core::OBJECT_CLASS.get_constant(:Rational)
          numeric_to_vm(context, r, rat_class)
        end

        def kernel_complex_from_string(context, _receiver, str_obj, exception_obj)
          exc = exception_obj.truthy?
          c = begin
            ::Kernel.Complex(str_obj.raw, exception: exc)
          rescue ::ArgumentError, ::Encoding::CompatibilityError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
          return FNIL if c.nil?
          c_class = Core::OBJECT_CLASS.get_constant(:Complex)
          rat_class = Core::OBJECT_CLASS.get_constant(:Rational)
          real_vm = numeric_to_vm(context, c.real, rat_class)
          imag_vm = numeric_to_vm(context, c.imaginary, rat_class)
          c_class.dispatch(context, :new, [real_vm, imag_vm], {})
        end

        def kernel_array(_, _receiver, val)
          return val if farray?(val)
          return FNIL.equal?(val) ? n2f_arr([]) : n2f_arr([val])
        end

        def kernel_dir(_, _receiver)
          stack = Fiber[:file_stack]
          return FNIL if stack.nil? || stack.empty?
          n2f_str(File.dirname(stack.last))
        end

        def kernel_require_relative(context, _receiver, path_obj)
          rel = path_obj.raw
          # Determine the base directory for the relative path.
          # MRI uses __FILE__ of the call site, which may be a synthetic path from instance_eval.
          # The incoming_call_site of the require_relative frame gives us the actual file.
          rr_frame = context.frames.reverse.find { |f| f.current_method&.name == :require_relative }
          call_site_file = rr_frame&.incoming_call_site&.then { |cs| cs.sub(/:(\d+)(:.*)?$/, "") }
          if call_site_file && call_site_file != "unknown"
            # Use the call site's file — supports synthetic paths from instance_eval.
            # Resolve symlinks via cache if this is a known loaded file.
            expanded = File.expand_path(call_site_file)
            current_real = Frozone::Vm::Vm::FILE_REALPATH_CACHE[expanded] || call_site_file
            base_dir = File.dirname(current_real)
          else
            stack = Fiber[:file_stack]
            raise "require_relative called outside of a file" if stack.nil? || stack.empty?
            current_real = Frozone::Vm::Vm::FILE_REALPATH_CACHE[stack.last] || stack.last
            base_dir = File.dirname(current_real)
          end
          full_path = File.expand_path(rel, base_dir)
          full_path += '.rb' unless full_path.end_with?('.rb')
          unless File.exist?(full_path)
            exc = FrozoneException.make(:LoadError, "cannot load such file -- #{full_path}")
            exc.vm_object.set_ivar(:@path, n2f_str(full_path))
            raise exc
          end
          loaded = GLOBALS[:"$LOADED_FEATURES"]
          loaded_paths = loaded.raw.map(&:raw)
          currently_loading = (Fiber[:currently_loading_files] ||= ::Set.new)
          if loaded_paths.include?(full_path) && currently_loading.include?(full_path)
            Frozone::Vm.emit_warning(context, "loading in progress, circular require considered harmful - #{full_path}")
            return FFALSE
          end
          return FFALSE if loaded_paths.include?(full_path)
          loaded.raw.push(n2f_str(full_path))
          currently_loading.add(full_path)
          begin
            Fiber[:vm_evaluate].call(full_path, raise_syntax_errors: true)
          rescue Ast::ReturnException
            # return at top level of required file stops loading gracefully
          rescue FrozoneException
            loaded.raw.delete_if { |s| s.raw == full_path }
            raise
          ensure
            currently_loading.delete(full_path)
          end
          FTRUE
        end

        def kernel_load(_, _receiver, path_obj, wrap_obj = FNIL)
          path = path_obj.raw
          path = ::File.expand_path(path) if path.start_with?('~')
          # load is strict: does NOT add .rb extension automatically
          # load DOES check CWD for bare paths (unlike require)
          full_path = if path.start_with?('/') || path.start_with?('./') || path.start_with?('../')
            expanded = ::File.expand_path(path)
            expanded if ::File.exist?(expanded)
          elsif ::File.exist?(path)
            path
          else
            load_path = GLOBALS[:"$LOAD_PATH"]
            found = nil
            load_path&.raw&.each do |dir_obj|
              dir = load_path_dir_str(dir_obj)
              next unless dir
              candidate = ::File.expand_path(::File.join(dir, path))
              if ::File.exist?(candidate)
                found = candidate
                break
              end
            end
            found
          end
          if full_path.nil?
            exc = FrozoneException.make(:LoadError, "cannot load such file -- #{path}")
            exc.vm_object.set_ivar(:@path, n2f_str(path))
            raise exc
          end
          wrap = wrap_obj && !fnil?(wrap_obj) && !ffalse?(wrap_obj)
          prev_wrap_mod = Fiber[:load_wrap_module]
          prev_wrap_receiver_sc_mods = Fiber[:load_wrap_receiver_sc_mods]
          if wrap
            # If a Module was passed, use it directly; otherwise create an anonymous module.
            wrap_mod = (fmod?(wrap_obj) && !fclass?(wrap_obj)) ? wrap_obj : ModuleObject.new(nil, nil)
            Fiber[:load_wrap_module] = wrap_mod
            # Pass the top-level self's singleton class modules so they appear in the wrapped self's ancestor chain.
            # Use bottom frame's the_self (the file-level main, same as MRI's rb_vm_top_self()).
            main_obj = _.frames.first&.the_self
            Fiber[:load_wrap_receiver_sc_mods] = main_obj&.eigenclass&.modules || []
          end
          begin
            Fiber[:vm_evaluate].call(full_path, raise_syntax_errors: true)
          rescue Ast::ReturnException
            # return at top level of loaded file stops loading gracefully
          rescue ::Errno::EACCES, ::Errno::EPERM => e
            exc = FrozoneException.make(:LoadError, "cannot load such file -- #{full_path}")
            exc.vm_object.set_ivar(:@path, n2f_str(full_path))
            raise exc
          ensure
            Fiber[:load_wrap_module] = prev_wrap_mod if wrap
            Fiber[:load_wrap_receiver_sc_mods] = prev_wrap_receiver_sc_mods if wrap
          end
          FTRUE
        end

        def kernel_binding(context, _receiver)
          # Capture the calling frame (frames[-2] since we're inside a kernel method call).
          # Skip send/__send__/public_send frames — they are transparent for binding purposes,
          # so m.send(:binding) captures the caller's binding (self), not the send-dispatched self.
          frames = context.frames
          idx = frames.length - 2
          while idx >= 0 && SEND_METHOD_NAMES.include?(frames[idx].current_method&.name)
            idx -= 1
          end
          captured_frame = idx >= 0 ? frames[idx] : context.frame
          # Source location: where `binding` was called (context.call_site set by MethodCall.evaluate)
          binding_call_site = context.call_site || captured_frame&.incoming_call_site
          BindingObject.new(captured_frame, binding_call_site)
        end

        def globals_trace_var_add(_context, _receiver, sym_obj, hook)
          name = fsym?(sym_obj) ? sym_obj.raw : sym_obj.raw.to_sym
          (TRACE_VAR_HOOKS[name] ||= []) << hook
          FNIL
        end

        def globals_trace_var_remove(_context, _receiver, sym_obj, cmd)
          name = fsym?(sym_obj) ? sym_obj.raw : sym_obj.raw.to_sym
          removed = if fnil?(cmd)
                      TRACE_VAR_HOOKS.delete(name) || []
                    else
                      hooks = TRACE_VAR_HOOKS[name] || []
                      hooks.reject! { |h| h.equal?(cmd) }
                      TRACE_VAR_HOOKS.delete(name) if hooks.empty?
                      hooks
                    end
          # Return array of removed hooks as ArrayObject
          arr = ArrayObject.new([])
          Array(removed).each { |h| arr.raw << h }
          arr
        end

        # Compute Prism forwarding flags from the binding frame's method, enabling
        # eval("foo(*)")  inside  def bar(*); ... end  etc.
        def compute_eval_forwarding(binding_frame)
          m = binding_frame.method_frame&.current_method
          return nil unless m.is_a?(Method)
          flags = []
          case m.rest_param
          when :__anon_rest__ then flags << :*
          when :__forward_args__, :__forward_kwargs__, :__forward_block__
            return [:'...']  # def foo(...) — full forwarding
          end
          flags << :** if m.kw_rest_param == :__anon_kwargs__
          flags << :& if m.block_param == :__anon_block__
          flags.empty? ? nil : flags
        end

        def kernel_eval(context, _receiver, code_obj, binding_arg = FNIL, filename_arg = FNIL, lineno_arg = FNIL)
          unless fstr?(code_obj)
            begin
              coerced = code_obj.dispatch(context, :to_str, [], {})
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{code_obj.class_object.name} into String") unless fstr?(coerced)
              code_obj = coerced
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{code_obj.class_object.name} into String")
            end
          end
          code = code_obj.raw
          eval_filename = f2n_raw(filename_arg)
          eval_lineno = fint?(lineno_arg) ? lineno_arg.raw : nil
          # If a BindingObject is passed, use its captured frame; otherwise use the caller's frame.
          # Non-nil/false non-Binding values raise TypeError.
          unless fnil?(binding_arg) || ffalse?(binding_arg)
            raise FrozoneException.make(:TypeError, "wrong argument type #{binding_arg.class_object.name} (expected binding)") unless binding_arg.is_a?(BindingObject)
          end
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
          # Compute anonymous parameter forwarding flags from the binding method's params
          # so that eval("foo(*)") works inside def bar(*); ... end
          eval_forwarding = compute_eval_forwarding(binding_frame)
          parser = EVAL_PARSER_CLASS.new(code, outer_locals: outer_locals, encoding: code_enc, filepath: eval_filepath, line: eval_lineno, forwarding: eval_forwarding)
          begin
            ast = parser.ast(raise_syntax_errors: true)
          rescue FrozoneException => e
            e.vm_object.set_ivar(:@path, n2f_str(eval_filename)) if eval_filename
            raise
          end
          # Emit Prism warnings: always-level (e.g. integer_in_flip_flop) and verbose-level when $VERBOSE
          parser.prism_always_warnings.each { |msg| Frozone::Vm.emit_warning(context, msg) }
          if GLOBALS.fetch(:"$VERBOSE", FFALSE).truthy?
            parser.prism_verbose_warnings.each { |msg| Frozone::Vm.emit_warning(context, msg) }
          end
          # Create eval frame using binding_frame's self/scopes (not the eval method frame),
          # so that `def`, `alias`, etc. use the correct lexical scope.
          # When called as ModuleName.eval (no binding), MRI uses the receiver as self.
          eval_self = (!binding_arg.is_a?(BindingObject) && _receiver.is_a?(ModuleObject)) ? _receiver : binding_frame.the_self
          new_frame = Frame.new(eval_self, parser.top_level_locals, binding_frame.scopes)
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
          # Exception: when eval is called as ModuleName.eval (no binding), the module IS the
          # def target, so skip def_scope inheritance (let method_def.rb use the_self directly).
          module_receiver_no_binding = !binding_arg.is_a?(BindingObject) && _receiver.is_a?(ModuleObject)
          inherited_def_scope = nil
          unless module_receiver_no_binding
            inherited_def_scope = binding_frame.def_scope
            if !inherited_def_scope && !binding_frame.the_self.is_a?(ModuleObject)
              walk = binding_frame.parent_frame
              while walk && !inherited_def_scope
                inherited_def_scope = walk.def_scope
                walk = walk.parent_frame
              end
            end
          end
          new_frame.def_scope = inherited_def_scope
          # Inherit active_refinements from binding_frame chain (for eval inside using/refine blocks)
          eval_refs = nil
          f = binding_frame
          while f
            eval_refs = f.active_refinements
            break if eval_refs && !eval_refs.empty?
            f = f.parent_frame
          end
          new_frame.active_refinements = eval_refs if eval_refs && !eval_refs.empty?
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

        private

        # Bare `raise` with no args: re-raise the current exception, or raise RuntimeError("").
        def reraise_current_or_runtime(cause, context)
          if cause
            set_exc_backtrace(cause, context) unless farray?(cause.get_ivar(:@backtrace))
            raise FrozoneException.new(cause, cause.get_ivar(:@message)&.raw || "")
          end
          exc = FrozoneException.make(:RuntimeError, "")
          set_exc_backtrace(exc.vm_object, context)
          raise exc
        end

        # `raise SomeClass[, "message"]` — call SomeClass.exception(message) to build instance.
        def raise_from_exception_class(context, klass, message_arg, backtrace_arg, cause, auto_cause: false)
          exc_obj = if message_arg && !fnil?(message_arg)
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
          if auto_cause && effective_cause && exc_obj.is_a?(ObjectObject)
            existing = exc_obj.get_ivar(:@cause)
            effective_cause = nil if existing && !fnil?(existing)
          end
          result = validate_cause(effective_cause, exc_obj, auto_cause: auto_cause)
          effective_cause = nil if result == :skip
          exc_obj.set_ivar(:@cause, effective_cause) if effective_cause
          apply_backtrace(exc_obj, backtrace_arg, context)
          raise FrozoneException.new(exc_obj, msg_str)
        end

        # `raise "message"` — create RuntimeError with string.
        def raise_from_string(context, msg, backtrace_arg, cause, auto_cause: false)
          exc = FrozoneException.make(:RuntimeError, msg.raw)
          effective_cause = (cause && !cause.equal?(exc.vm_object)) ? cause : nil
          result = validate_cause(effective_cause, exc.vm_object, auto_cause: auto_cause)
          effective_cause = nil if result == :skip
          exc.vm_object.set_ivar(:@cause, effective_cause) if effective_cause
          apply_backtrace(exc.vm_object, backtrace_arg, context)
          raise exc
        end

        # `raise exception_object` — use the #exception protocol.
        def raise_from_exception_protocol(context, msg, message_arg, backtrace_arg, cause, auto_cause: false)
          has_message_arg = !fnil?(message_arg)
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
          msg_str = fstr?(msg_str) ? msg_str.raw : "exception"
          effective_cause = (cause && !cause.equal?(exc_obj)) ? cause : nil
          if auto_cause && effective_cause && exc_obj.is_a?(ObjectObject)
            existing = exc_obj.get_ivar(:@cause)
            effective_cause = nil if existing && !fnil?(existing)
          end
          result = validate_cause(effective_cause, exc_obj, auto_cause: auto_cause)
          effective_cause = nil if result == :skip
          exc_obj.set_ivar(:@cause, effective_cause) if effective_cause && exc_obj.is_a?(ObjectObject)
          # Only set backtrace if explicitly provided or exception has no backtrace yet
          apply_backtrace(exc_obj, backtrace_arg, context) unless exc_obj.is_a?(ObjectObject) && farray?(exc_obj.get_ivar(:@backtrace))
          raise FrozoneException.new(exc_obj, msg_str)
        end

        def kernel_exec_daemon(_, _receiver, stay_obj, keep_obj)
          stay = stay_obj.truthy?
          keep = keep_obj.truthy?
          n2f_int(::Process.daemon(stay, keep))
        end
      end
    end
  end
end
