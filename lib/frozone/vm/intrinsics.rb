module Frozone
  module Vm
    module Intrinsics
      class << self
        # Object
        def object_class(_, v) = v.class_object

        def object_is_a(_, v, klass)
          # Check eigenclass first (every object is kind_of? its singleton class)
          if v.respond_to?(:eigenclass) && v.eigenclass
            ec = v.eigenclass
            return TrueObject::TRUE if ec.equal?(klass)
          end
          # Singleton classes of classes are instances of Class's singleton class
          # (and that singleton class's singleton class, etc.)
          if klass.respond_to?(:is_singleton_class) && klass.is_singleton_class &&
             v.respond_to?(:is_singleton_class) && v.is_singleton_class
            sc_of_v = v.singleton_of
            sc_of_k = klass.singleton_of
            if sc_of_v.is_a?(ClassObject) && sc_of_k.is_a?(ClassObject)
              # v = #<Class:SomeClass>, klass = #<Class:SomeOtherClass>
              # v.kind_of?(klass) iff SomeClass.kind_of?(SomeOtherClass_class)
              # i.e. SomeClass is an instance of SomeOtherClass
              return object_is_a(nil, sc_of_v, sc_of_k)
            end
          end
          c = v.respond_to?(:class_object) ? v.class_object : nil
          until c.nil?
            return TrueObject::TRUE if c.equal?(klass)
            return TrueObject::TRUE if c.respond_to?(:prepends) && c.prepends.any? { |m| m.equal?(klass) }
            return TrueObject::TRUE if c.respond_to?(:modules) && c.modules.any? { |m| m.equal?(klass) }
            c = c.respond_to?(:superclass) ? c.superclass : nil
          end
          FalseObject::FALSE
        end

        def object_ivar_get(_, v, name)
          ivar_name_str = name.is_a?(SymbolObject) ? name.raw.to_s : name.raw.to_s
          unless ivar_name_str.start_with?('@') && ivar_name_str.length > 1
            raise ivar_name_error("'#{ivar_name_str}' is not allowed as an instance variable name", name, v)
          end
          v.get_ivar(normalize_ivar(name))
        end

        def object_ivar_set(_, v, name, value)
          ivar_name_str = name.is_a?(SymbolObject) ? name.raw.to_s : name.raw.to_s
          unless ivar_name_str.start_with?('@') && ivar_name_str.length > 1
            raise ivar_name_error("'#{ivar_name_str}' is not allowed as an instance variable name", name, v)
          end
          v.set_ivar(normalize_ivar(name), value)
          value
        end

        def object_ivar_defined(_, v, name)
          ivar_name_str = name.is_a?(SymbolObject) ? name.raw.to_s : name.raw.to_s
          unless ivar_name_str.start_with?('@') && ivar_name_str.length > 1
            raise ivar_name_error("'#{ivar_name_str}' is not allowed as an instance variable name", name, v)
          end
          bool_object_for(v.ivar_defined?(normalize_ivar(name)))
        end

        def ivar_name_error(msg, name_obj, receiver)
          exc = FrozoneException.make(:NameError, msg)
          # Set @name to the original VM object (may be String) for identity equality in tests
          exc.vm_object.set_ivar(:@name, name_obj)
          exc.vm_object.set_ivar(:@receiver, receiver)
          exc
        end

        def object_ivar_names(_, v)
          names = v.instance_variables_hash&.keys || []
          ArrayObject.new(names.map { |k| SymbolObject.from(k) })
        end

        def object_ivar_remove(_, v, name)
          k = normalize_ivar(name)
          ivars = v.instance_variables_hash
          raise FrozoneException.make(:NameError, "instance variable #{k} not defined") unless ivars&.key?(k)
          ivars.delete(k)
        end

        def object_respond_to(context, v, name, include_private_obj = FalseObject::FALSE)
          include_private = include_private_obj.truthy?
          m = v.lookup_instance_method(name.raw)
          if m
            bool_object_for(include_private || m.visibility == :public)
          else
            begin
              result = v.dispatch(context, :respond_to_missing?, [name, include_private_obj], {})
              result.truthy? ? TrueObject::TRUE : FalseObject::FALSE
            rescue FrozoneException
              FalseObject::FALSE
            end
          end
        end

        def object_methods(_, v, include_super_obj = TrueObject::TRUE)
          collect_method_names(v, include_super_obj.truthy?) { |vis| vis != :private }
        end

        def object_public_methods(_, v, include_super_obj = TrueObject::TRUE)
          collect_method_names(v, include_super_obj.truthy?) { |vis| vis == :public }
        end

        def object_dup(context, v)
          # Only works for plain ObjectObject instances — specialized types (String, Array, etc.)
          # define their own dup methods in core Ruby.
          return v unless v.class == ObjectObject
          copy = ObjectObject.allocate
          copy.class_object = v.class_object
          copy.copy_fields_from(v, eigenclass: nil, frozen: false)
          copy.dispatch(context, :initialize_copy, [v], {}, nil, private_ok: true)
          copy
        end

        def object_clone(_, v, freeze_opt = NilObject::NIL)
          # Only works for plain ObjectObject instances — specialized types define their own clone.
          return v unless v.class == ObjectObject
          copy = ObjectObject.allocate
          copy.class_object = v.class_object
          sc_copy = v.eigenclass ? ClassObject.clone_singleton(v.eigenclass, copy) : nil
          freeze_val = freeze_opt.is_a?(NilObject) ? nil : freeze_opt.truthy?
          frozen = freeze_val == false ? false : freeze_val.nil? ? v.frozen_object? : true
          copy.copy_fields_from(v, eigenclass: sc_copy, frozen: frozen)
        end

        def string_initialize(context, receiver, str_arg, _encoding = NilObject::NIL)
          # Convert str_arg to string if needed
          str_val = str_arg.is_a?(StringObject) ? str_arg.raw : str_arg.dispatch(context, :to_s, [], {}).raw
          receiver.raw = str_val.dup
          NilObject::NIL
        end

        def string_clone(_, v, freeze_opt = NilObject::NIL)
          copy = StringObject.new(v.raw.dup)
          sc_copy = v.eigenclass ? ClassObject.clone_singleton(v.eigenclass, copy) : nil
          freeze_val = freeze_opt.is_a?(NilObject) ? nil : freeze_opt.truthy?
          frozen = freeze_val == false ? false : freeze_val.nil? ? v.frozen_object? : true
          copy.copy_fields_from(v, eigenclass: sc_copy, frozen: frozen)
        end

        def object_freeze(_, v)
          v.freeze_object!
          v
        end

        def object_frozen(_, v)
          # Integers, Symbols, nil, true, false are always frozen
          return TrueObject::TRUE if v.is_a?(IntegerObject) || v.is_a?(SymbolObject) ||
                                     v.is_a?(NilObject) || v.is_a?(TrueObject) || v.is_a?(FalseObject)
          bool_object_for(v.frozen_object?)
        end

        def object_singleton_class(_, v)
          # Integer and Symbol don't have singleton classes
          if v.is_a?(IntegerObject) || v.is_a?(SymbolObject)
            raise FrozoneException.make(:TypeError, "can't define singleton for #{v.class_object.name}")
          end
          # true/false/nil return their class (they are singleton instances)
          if v.is_a?(TrueObject) || v.is_a?(FalseObject) || v.is_a?(NilObject)
            return v.class_object
          end
          v.singleton_class
        end

        def object_singleton_methods(_, v, include_super_obj = TrueObject::TRUE)
          return ArrayObject.new([]) if v.eigenclass.nil?
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          sc = v.singleton_class
          sources = include_super ? sc.ancestors_list : [sc]
          sources.each do |mod|
            mod.methods_table.each do |name, meth|
              next if seen[name]
              seen[name] = true
              next if meth == ModuleObject::UNDEF_SENTINEL
              next if meth.visibility == :private
              result << SymbolObject.from(name)
            end
          end
          ArrayObject.new(result)
        end

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

        def io_print(context, receiver, args)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          args.raw.each { |a| native.print(a.dispatch(context, :to_s, [], {}).raw) }
          NilObject::NIL
        end

        def io_puts(context, receiver, args)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          if args.raw.empty?
            native.puts
          else
            args.raw.each { |a| native.puts(a.dispatch(context, :to_s, [], {}).raw) }
          end
          NilObject::NIL
        end

        def io_write(context, receiver, args)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          str = args.raw.first
          s = str.dispatch(context, :to_s, [], {}).raw
          native.write(s)
          IntegerObject.new(s.bytesize)
        end

        def io_flush(_, receiver)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          native.flush rescue nil
          receiver
        end

        def io_sync_set(_, receiver, val)
          native = receiver.is_a?(IOObject) ? receiver.native_io : $stdout
          native.sync = val.truthy? rescue nil
          val
        end

        def io_popen_capture(_, cmd)
          cmd_str = if cmd.is_a?(ArrayObject)
            require 'shellwords'
            cmd.raw.map { |a| a.is_a?(StringObject) ? a.raw : a.to_s }.shelljoin
          elsif cmd.is_a?(StringObject)
            cmd.raw
          else
            cmd.to_s
          end
          output = ::IO.popen(cmd_str, 'r', &:read) rescue ""
          StringObject.new(output || "")
        end

        def io_external_encoding(_, receiver)
          return NilObject::NIL unless receiver.is_a?(IOObject)
          enc = receiver.native_io.external_encoding rescue nil
          enc ? StringObject.new(enc.name) : NilObject::NIL
        end

        # Build a VM backtrace from the current context frames.
        # Skips the 'raise'/'fail' wrapper frame (Kernel#raise is transparent in backtraces).
        def build_vm_backtrace(context)
          bt = []
          all_frames = context.frames.reverse  # innermost first
          # Use call-site approach: each entry shows WHERE this frame was called from
          # plus the method name of the CALLING frame. This naturally places errors at
          # the call site and omits internal frames (like method_missing) from the top.
          i = 0
          while i < all_frames.length - 1
            frame = all_frames[i]
            outer_frame = all_frames[i + 1]
            loc = frame.incoming_call_site || "unknown:0"
            meth = outer_frame.current_method&.name || :"<main>"
            bt << StringObject.new("#{loc}:in '#{meth}'", frozen: true)
            i += 1
          end
          # Outermost frame: use its incoming_call_site with <main>
          if i < all_frames.length
            outer = all_frames[i]
            loc = outer.incoming_call_site || (outer.current_method&.source_location) || "unknown:0"
            bt << StringObject.new("#{loc}:in '<main>'", frozen: true)
          end
          ArrayObject.new(bt)
        end

        def set_exc_backtrace(exc_obj, context)
          bt = build_vm_backtrace(context)
          unless exc_obj.is_a?(NilObject)
            exc_obj.set_ivar(:@backtrace, bt)
            exc_obj.set_ivar(:@_has_locations, TrueObject::TRUE)
          end
        end

        # Build the Ruby caller() array from the current frame stack.
        # `start` — how many logical entries to skip (0 = include the frame that called caller)
        # `length` — max entries to return (nil = all)
        def kernel_caller(context, _receiver, start_obj = NilObject::NIL, length_obj = NilObject::NIL)
          start  = start_obj.is_a?(IntegerObject)  ? start_obj.raw : 1
          length = length_obj.is_a?(IntegerObject) ? length_obj.raw : nil

          all_frames = context.frames.reverse  # most recent first

          # Find the last :caller frame — that's where entries begin
          last_caller_idx = all_frames.rindex { |f| f.current_method&.name == :caller } || -1
          base = [last_caller_idx, 0].max

          # Each entry i (0-based) represents:
          #   line/file  = all_frames[base + i].incoming_call_site  (where the call originated)
          #   method     = all_frames[base + i + 1].current_method.name (method that was running)
          entries = []
          i = base
          while i < all_frames.length - 1
            loc  = all_frames[i].incoming_call_site || "unknown:0"
            meth = all_frames[i + 1].current_method&.name&.to_s || "block"
            entries << StringObject.new("#{loc}:in '#{meth}'", frozen: true)
            i += 1
          end

          # Apply start offset and length
          sliced = length ? entries[start, length] : entries[start..]
          ArrayObject.new(sliced || [])
        end

        def kernel_raise(context, _receiver, msg = NilObject::NIL, message_arg = nil, _backtrace = nil, cause_arg = nil)
          current_exc = GLOBALS[:"$!"]
          no_cause_sentinel = cause_arg.is_a?(SymbolObject) && cause_arg.raw == :__raise_no_cause__
          cause = if cause_arg.nil? || no_cause_sentinel
            (current_exc && !current_exc.is_a?(NilObject)) ? current_exc : nil
          elsif cause_arg.is_a?(NilObject)
            nil
          else
            cause_arg
          end

          if msg.is_a?(NilObject)
            # bare `raise` re-raises current exception or raises RuntimeError with empty message
            if cause
              set_exc_backtrace(cause, context) unless cause.get_ivar(:@backtrace).is_a?(ArrayObject)
              raise FrozoneException.new(cause, cause.get_ivar(:@message)&.raw || "")
            end
            exc = FrozoneException.make(:RuntimeError, "")
            set_exc_backtrace(exc.vm_object, context)
            raise exc
          elsif msg.is_a?(ClassObject) || msg.is_a?(ModuleObject)
            # raise SomeClass[, "message"] — call SomeClass.exception(message) to build instance
            exc_obj = if message_arg
              msg.dispatch(context, :exception, [message_arg], {})
            else
              msg.dispatch(context, :exception, [], {})
            end
            msg_str = begin
              exc_obj.dispatch(context, :message, [], {}).raw
            rescue StandardError
              msg.name.to_s
            end
            exc_obj.set_ivar(:@cause, cause) if cause
            set_exc_backtrace(exc_obj, context)
            raise FrozoneException.new(exc_obj, msg_str)
          elsif msg.is_a?(StringObject)
            exc = FrozoneException.make(:RuntimeError, msg.raw)
            exc.vm_object.set_ivar(:@cause, cause) if cause
            set_exc_backtrace(exc.vm_object, context)
            raise exc
          else
            # raise exception_object (must respond to message)
            begin
              msg_str = msg.dispatch(context, :message, [], {})
              msg_str = msg_str.is_a?(StringObject) ? msg_str.raw : msg.to_s
            rescue
              msg_str = "exception"
            end
            # Don't set cause when re-raising the same exception that's in $!
            msg.set_ivar(:@cause, cause) if cause && !cause.equal?(msg) && msg.respond_to?(:set_ivar)
            set_exc_backtrace(msg, context)
            raise FrozoneException.new(msg, msg_str)
          end
        end

        def exception_caller_string(context)
          # Return a caller location string for full_message when exception has no backtrace.
          # We want the call site where full_message was invoked, which is stored as the
          # incoming_call_site of the full_message frame (last internal frame we skip over).
          all_frames = context.frames.reverse
          # Skip internal frames (full_message, detailed_message, exception_caller_string)
          i = 0
          skip = %i[full_message detailed_message exception_caller_string _full_message_dm _format_single_full_message]
          i += 1 while i < all_frames.length && skip.include?(all_frames[i].current_method&.name)
          return NilObject::NIL if i.zero?
          # The last skipped frame (i-1) has incoming_call_site = where full_message was called from
          loc = all_frames[i - 1].incoming_call_site
          return NilObject::NIL unless loc
          outer_name = i < all_frames.length ? (all_frames[i].current_method&.name&.to_s || "<main>") : "<main>"
          StringObject.new("#{loc}:in '#{outer_name}'")
        end

        def exception_tty_check(_context = nil)
          $stderr.isatty ? TrueObject::TRUE : FalseObject::FALSE
        end

        def signal_trap(context, signal, block_arg = NilObject::NIL)
          # Stub: signal trapping not fully implemented
          NilObject::NIL
        end

        def kernel_p(context, _receiver, args)
          args.raw.each { |a| $stdout.puts(a.dispatch(context, :inspect, [], {}).raw) }
          args.raw.length == 1 ? args.raw.first : args
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
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          loop do
            block.invoke(context, [])
          rescue Ast::BreakException => e
            return e.value
          end
          NilObject::NIL
        end

        def kernel_catch(context, _receiver, tag, block)
          tag_raw = tag.is_a?(NilObject) ? :__catch_nil__ : tag.respond_to?(:raw) ? tag.raw : tag
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
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
        BUNDLER_NOISE_RE = /\A.+(?:bundler\/rubygems_ext\.rb|rubygems\/platform\.rb):\d+: warning: (?:already initialized constant|previous definition of) /

        def kernel_backtick(_, _receiver, cmd_obj)
          result = `#{cmd_obj.raw}`
          GLOBALS[:"$?"] = ProcessStatusObject.new($?)
          filtered = result.lines.reject { |l| BUNDLER_NOISE_RE.match?(l) }.join
          StringObject.new(filtered)
        end

        def process_status_exitstatus(_, obj)
          IntegerObject.new(obj.native_status.exitstatus || 0)
        end

        def process_status_pid(_, obj)
          IntegerObject.new(obj.native_status.pid || 0)
        end

        def emit_vm_warning(context, msg)
          Frozone::Vm.emit_warning(context, msg)
        end

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

        def kernel_rand(_, _receiver, n)
          if n.nil? || n.is_a?(NilObject)
            FloatObject.new(rand)
          elsif n.is_a?(IntegerObject)
            IntegerObject.new(rand(n.raw))
          elsif n.is_a?(FloatObject)
            FloatObject.new(rand(n.raw))
          elsif n.is_a?(RangeObject)
            result = rand(n.raw)
            result.is_a?(Integer) ? IntegerObject.new(result) : FloatObject.new(result)
          else
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{n.class} into Integer")
          end
        end

        def kernel_srand(_, _receiver, seed)
          result = seed.nil? || seed.is_a?(NilObject) ? srand : srand(seed.raw)
          IntegerObject.new(result)
        end

        def random_new(_, _receiver, seed)
          raw_seed = seed.nil? || seed.is_a?(NilObject) ? nil : seed.raw
          RandomObject.new(raw_seed)
        end

        def random_rand(_, v, n)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          if n.nil? || n.is_a?(NilObject)
            FloatObject.new(rng.rand)
          elsif n.is_a?(IntegerObject)
            IntegerObject.new(rng.rand(n.raw))
          elsif n.is_a?(FloatObject)
            FloatObject.new(rng.rand(n.raw))
          elsif n.is_a?(RangeObject)
            result = rng.rand(n.raw)
            result.is_a?(Integer) ? IntegerObject.new(result) : FloatObject.new(result)
          else
            raise FrozoneException.make(:TypeError, "no implicit conversion of #{n.class_object&.name} into Integer")
          end
        end

        def random_seed(_, v)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          IntegerObject.new(rng.seed)
        end

        def random_new_seed(_, _receiver)
          IntegerObject.new(Random.new_seed)
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
          exc = if Fiber[:mm_implicit_self]
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

        def no_method_receiver_desc(receiver)
          ctx = Fiber[:context]
          if receiver.equal?(NilObject::NIL)
            "nil"
          elsif receiver.equal?(TrueObject::TRUE)
            "true"
          elsif receiver.equal?(FalseObject::FALSE)
            "false"
          elsif receiver.is_a?(ClassObject)
            if receiver.is_singleton_class
              singleton_of = receiver.singleton_of
              inner = singleton_of ? "#<#{singleton_of.class_object&.name || "Object"}:0x#{singleton_of.__id__.to_s(16)}>" : "0x#{receiver.__id__.to_s(16)}"
              label = "#<Class:#{inner}>"
            else
              n = begin; ctx ? receiver.dispatch(ctx, :name, [], {})&.raw : receiver.name; rescue StandardError; receiver.name; end
              label = n ? n.to_s : "#<Class:0x#{receiver.__id__.to_s(16)}>"
            end
            "class #{label}"
          elsif receiver.is_a?(ModuleObject)
            n = begin; ctx ? receiver.dispatch(ctx, :name, [], {})&.raw : receiver.name; rescue StandardError; receiver.name; end
            label = n ? n.to_s : "#<Module:0x#{receiver.__id__.to_s(16)}>"
            "module #{label}"
          elsif receiver.eigenclass
            # Has singleton class — use inspect-like representation
            klass = receiver.class_object
            class_name = begin; ctx ? klass.dispatch(ctx, :name, [], {})&.raw : klass.name; rescue StandardError; klass.name; end
            class_name ||= "#<Class:0x#{klass.__id__.to_s(16)}>"
            "#<#{class_name}:0x#{receiver.__id__.to_s(16)}>"
          else
            klass = receiver.class_object
            class_name = begin; ctx ? klass.dispatch(ctx, :name, [], {})&.raw : klass.name; rescue StandardError; klass.name; end
            class_name ||= "#<Class:0x#{klass.__id__.to_s(16)}>"
            "an instance of #{class_name}"
          end
        end

        def basic_object___send__(context, receiver, name, args, kwargs, block_arg = nil)
          method_name = name.is_a?(SymbolObject) ? name.raw : name.raw.to_sym
          raw_kwargs = kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k }
          block_obj = block_arg.is_a?(ProcObject) ? block_arg.block_object : block_arg
          block_obj = nil if block_obj.is_a?(NilObject)
          receiver.dispatch(context, method_name, args.raw, raw_kwargs, block_obj, private_ok: true)
        end

        def object_public_send(context, receiver, name, args, kwargs, block_arg = nil)
          method_name = name.is_a?(SymbolObject) ? name.raw : name.raw.to_sym
          raw_kwargs = kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k }
          block_obj = block_arg.is_a?(ProcObject) ? block_arg.block_object : block_arg
          block_obj = nil if block_obj.is_a?(NilObject)
          receiver.dispatch(context, method_name, args.raw, raw_kwargs, block_obj, private_ok: false, public_only: true)
        end

        # Module
        def module_include(_, receiver, mod)
          receiver.add_module(mod)
          receiver
        end

        def toplevel_include(_, _self, mods)
          mods.raw.each { |mod| Core::OBJECT_CLASS.add_module(mod) }
          Core::OBJECT_CLASS
        end

        def module_prepend(_, receiver, mod)
          receiver.prepend_module(mod)
          receiver
        end

        def object_instance_eval(context, receiver, block)
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          return block.invoke(context, [], receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(ProcObject)
          return block.invoke(context, [], receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(BlockObject)
          NilObject::NIL
        end

        def object_instance_eval_string(context, receiver, code_obj)
          return NilObject::NIL unless code_obj.is_a?(StringObject)
          code = code_obj.raw
          parser = Parser.new(code)
          ast = parser.ast
          # Evaluate with self = receiver (the object), using its class as scope
          new_frame = Frame.new(receiver, parser.top_level_locals, context.frame.scopes)
          # `def` inside instance_eval always targets receiver's singleton class
          new_frame.def_scope = receiver.singleton_class
          context.push_frame(new_frame)
          begin
            ast.evaluate(context)
          ensure
            context.pop_frame
          end
        end

        def object_instance_exec(context, receiver, args, block)
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          return block.invoke(context, args.raw, receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(ProcObject)
          return block.invoke(context, args.raw, receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(BlockObject)
          NilObject::NIL
        end

        def object_extend(_, receiver, mod)
          receiver.singleton_class.add_module(mod)
          receiver
        end

        # Thread-local global isolation: save $_ and $? before running Thread body.
        THREAD_SAVED_LOCALS = {}

        def thread_save_reset_locals(_, thread_obj)
          THREAD_SAVED_LOCALS[thread_obj.object_id] = {
            dollar_underscore: GLOBALS.fetch(:"$_", NilObject::NIL),
            dollar_question:   GLOBALS.fetch(:"$?", NilObject::NIL)
          }
          GLOBALS[:"$_"] = NilObject::NIL
          GLOBALS.delete(:"$?")
          NilObject::NIL
        end

        def thread_restore_locals(_, thread_obj)
          saved = THREAD_SAVED_LOCALS.delete(thread_obj.object_id) || {}
          GLOBALS[:"$_"] = saved[:dollar_underscore] || NilObject::NIL
          if saved[:dollar_question] && !saved[:dollar_question].is_a?(NilObject)
            GLOBALS[:"$?"] = saved[:dollar_question]
          else
            GLOBALS.delete(:"$?")
          end
          NilObject::NIL
        end

        def thread_run_block(context, block_obj)
          bo = block_obj.is_a?(ProcObject) ? block_obj.block_object : block_obj
          bo.invoke(context, [], thread_boundary: true)
        end

        def fiber_new(_, _klass, block_obj)
          bo = block_obj.is_a?(ProcObject) ? block_obj.block_object : block_obj
          FiberObject.new(bo)
        end

        def fiber_resume(context, fiber_obj, args)
          raise FrozoneException.make(:TypeError, "can't resume a non-Fiber object") unless fiber_obj.is_a?(FiberObject)
          fiber_obj.resume(context, args.raw)
        end

        def fiber_yield(_, _receiver, args)
          ::Fiber.yield(args.raw.first || NilObject::NIL)
        end

        def fiber_current(_context, _receiver)
          # Return the current Frozone FiberObject if inside one, else NilObject
          ::Fiber[:frozone_fiber_obj] || NilObject::NIL
        end

        def fiber_alive(_, fiber_obj)
          bool_object_for(fiber_obj.is_a?(FiberObject) && fiber_obj.alive?)
        end

        def fiber_storage_get(_context, _receiver, key_obj)
          sym = key_obj.is_a?(SymbolObject) ? key_obj.raw : key_obj.to_sym
          ::Fiber[sym] || NilObject::NIL
        end

        def fiber_storage_set(_context, _receiver, key_obj, val)
          sym = key_obj.is_a?(SymbolObject) ? key_obj.raw : key_obj.to_sym
          ::Fiber[sym] = val
          val
        end

        def module_ruby2_keywords(_, receiver, names_array)
          names_array.raw.each do |name_obj|
            name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
            m = receiver.is_a?(ClassObject) ? receiver.lookup_method(name) : receiver.get_method(name)
            m.ruby2_keywords = true if m.respond_to?(:ruby2_keywords=)
          end
          receiver
        end

        def module_undef_method(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          # Check if method exists anywhere in hierarchy
          existing = receiver.is_a?(ClassObject) ? receiver.lookup_method(name) : receiver.get_method(name)
          raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'") if existing.nil?
          receiver.undef_method(name)
          receiver
        end

        def module_alias_method(_, receiver, new_name_obj, old_name_obj)
          new_name = new_name_obj.is_a?(SymbolObject) ? new_name_obj.raw : new_name_obj.raw.to_sym
          old_name = old_name_obj.is_a?(SymbolObject) ? old_name_obj.raw : old_name_obj.raw.to_sym
          method = receiver.is_a?(ClassObject) ? receiver.lookup_method(old_name) : receiver.get_method(old_name)
          raise FrozoneException.make(:NameError, "undefined method '#{old_name}'") if method.nil?
          receiver.set_method(new_name, method.alias_as(new_name))
          receiver
        end

        def module_define_method(_, receiver, name_obj, block)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          method = if block.is_a?(UnboundMethodObject)
                     raw = block.raw_method
                     raw.is_a?(Method) ? raw.bound_copy(name, receiver) : DefinedMethod.new(name, raw.block_obj, receiver)
                   elsif block.is_a?(ProcObject)
                     DefinedMethod.new(name, block.block_object, receiver)
                   else
                     DefinedMethod.new(name, block, receiver)
                   end
          receiver.set_method(name, method)
          SymbolObject.from(name)
        end

        def module_constants(_, receiver)
          names = []
          c = receiver
          while c
            c.constants_table.each_key { |k| names << SymbolObject.from(k) }
            c = c.is_a?(ClassObject) ? c.superclass : nil
          end
          ArrayObject.new(names.uniq)
        end

        def module_class_variable_defined(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          receiver.class_variables.key?(name) ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_class_variables(_, receiver)
          ArrayObject.new(receiver.class_variables.keys.map { |k| SymbolObject.from(k) })
        end

        def module_class_variable_get(_, receiver, name_obj)
          name_str = name_obj.is_a?(SymbolObject) ? name_obj.raw.to_s : name_obj.raw.to_s
          unless name_str.start_with?('@@') && name_str.length > 2
            exc = FrozoneException.make(:NameError, "`#{name_str}' is not allowed as a class variable name")
            exc.vm_object.set_ivar(:@name, name_obj)
            exc.vm_object.set_ivar(:@receiver, receiver)
            raise exc
          end
          name = name_str.to_sym
          val = receiver.get_class_var(name)
          if val.nil?
            exc = FrozoneException.make(:NameError, "uninitialized class variable #{name} in #{receiver.name}", name: name)
            exc.vm_object.set_ivar(:@receiver, receiver)
            raise exc
          end
          val
        end

        def module_class_variable_set(_, receiver, name_obj, value)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          receiver.set_class_var(name, value)
          value
        end

        def module_private_constant(_, receiver, *name_objs)
          name_objs.each do |name_obj|
            name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
            receiver.mark_constant_private(name)
          end
          receiver
        end

        def module_public_constant(_, receiver, *name_objs)
          name_objs.each do |name_obj|
            name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
            receiver.private_constants_table&.delete(name)
          end
          receiver
        end

        def module_remove_const(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          val = receiver.get_constant(name)
          raise FrozoneException.make(:NameError, "constant #{name} not defined") if val.nil?
          receiver.constants_table.delete(name)
          val
        end

        def module_remove_class_variable(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          raise FrozoneException.make(:NameError, "class variable #{name} not defined for #{receiver.name}") unless receiver.class_variables.key?(name)
          receiver.class_variables.delete(name) || NilObject::NIL
        end

        def module_name(_, receiver)
          return NilObject::NIL unless receiver.name
          StringObject.new(receiver.full_name.to_s)
        end

        def module_const_defined(_, receiver, name_obj, inherit = TrueObject::TRUE)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          c, = receiver.lookup_constant_with_owner(name)
          !c.nil? ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_const_get(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          c = receiver.get_constant(name)
          raise FrozoneException.make(:NameError, "uninitialized constant #{receiver.name}::#{name}") if c.nil?
          c
        end

        def module_const_set(context, receiver, name_obj, value)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          name_s = name.to_s
          raise FrozoneException.make(:NameError, "wrong constant name #{name_s}") unless name_s =~ /\A[[:upper:]]/
          emit_vm_warning(context, "already initialized constant #{receiver.name}::#{name}") if receiver.get_constant(name)
          receiver.set_constant(name, value)
          value
        end

        def module_eval(context, receiver, block)
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          prev_vis = receiver.is_a?(ModuleObject) ? receiver.current_visibility : nil
          receiver.current_visibility = :public if prev_vis
          context.scopes << receiver
          begin
            block.invoke(context, [], receiver: receiver)
          ensure
            context.scopes.pop
            receiver.current_visibility = prev_vis if prev_vis
          end
        end

        def module_exec(context, receiver, args_obj, block)
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          args = args_obj.is_a?(ArrayObject) ? args_obj.raw : []
          prev_vis = receiver.is_a?(ModuleObject) ? receiver.current_visibility : nil
          receiver.current_visibility = :public if prev_vis
          context.scopes << receiver
          begin
            block.invoke(context, args, receiver: receiver)
          ensure
            context.scopes.pop
            receiver.current_visibility = prev_vis if prev_vis
          end
        end

        def module_eval_string(context, receiver, code_obj)
          code = code_obj.raw
          parser = Parser.new(code)
          ast = parser.ast
          # Evaluate in a frame where self = receiver (the module/class)
          new_frame = Frame.new(receiver, parser.top_level_locals, context.frame.scopes + [receiver])
          context.push_frame(new_frame)
          context.scopes << receiver
          begin
            ast.evaluate(context)
          ensure
            context.pop_frame
            context.scopes.pop
          end
        end

        def module_ancestors(_, receiver)
          result = []
          walk = lambda do |mod|
            mod.prepends.each { |m| walk.call(m) }
            result << mod
            mod.modules.each { |m| walk.call(m) }
            if mod.is_a?(ClassObject) && mod.superclass
              walk.call(mod.superclass)
            end
          end
          walk.call(receiver)
          ArrayObject.new(result)
        end

        def module_instance_methods(_, receiver, include_super_obj = TrueObject::TRUE)
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          collect = lambda do |mod|
            mod.methods_table.each do |name, m|
              next if seen[name]
              seen[name] = true
              result << SymbolObject.from(name) if m.visibility == :public || m.visibility == :protected
            end
          end
          if include_super
            walk = lambda do |mod|
              mod.prepends.each { |m| walk.call(m) }
              collect.call(mod)
              mod.modules.each { |m| walk.call(m) }
              walk.call(mod.superclass) if mod.is_a?(ClassObject) && mod.superclass
            end
            walk.call(receiver)
          else
            collect.call(receiver)
          end
          ArrayObject.new(result)
        end

        def module_method_defined(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          m = receiver.get_method(name)
          m && (m.visibility == :public || m.visibility == :protected) ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_private_instance_methods(_, receiver, include_super_obj = TrueObject::TRUE)
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          collect = lambda do |mod|
            mod.methods_table.each do |name, m|
              next if seen[name]
              seen[name] = true
              result << SymbolObject.from(name) if m.visibility == :private
            end
          end
          if include_super
            walk = lambda do |mod|
              mod.prepends.each { |m| walk.call(m) }
              collect.call(mod)
              mod.modules.each { |m| walk.call(m) }
              walk.call(mod.superclass) if mod.is_a?(ClassObject) && mod.superclass
            end
            walk.call(receiver)
          else
            collect.call(receiver)
          end
          ArrayObject.new(result)
        end

        def module_instance_method(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          m = receiver.lookup_method(name)
          unless m
            raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
          end
          owner = receiver.lookup_method_owner(name) || receiver
          UnboundMethodObject.new(m, name, owner)
        end

        def object_method(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          klass = receiver.eigenclass || receiver.class_object
          m = klass.lookup_method(name) || receiver.class_object.lookup_method(name)
          unless m
            raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.class_object.full_name}'")
          end
          owner = receiver.class_object.lookup_method_owner(name) || receiver.class_object
          BoundMethodObject.new(m, name, receiver, owner)
        end

        def bound_method_call(context, receiver, args, kwargs)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          blk = context.frame.block
          blk = nil if blk.nil? || blk.is_a?(NilObject)
          kw = kwargs.is_a?(HashObject) ? kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k.raw.to_sym } : {}
          receiver.bound_receiver.dispatch(context, receiver.bound_name, args.raw, kw, blk)
        end

        def bound_method_arity(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          return IntegerObject.new(0) unless m.is_a?(Method)
          req = m.required_params.length
          opt = m.optional_params.length
          rest = m.rest_param && m.rest_param != :__no_rest__
          post = m.post_params.length
          req_kw = m.required_kw_params.length
          opt_kw = m.optional_kw_params.length
          kw_rest = m.kw_rest_param
          req_kw_count = req_kw > 0 ? 1 : 0
          kw_optional = req_kw == 0 && (opt_kw > 0 || (kw_rest && kw_rest != :__no_kwargs__))
          has_opt = rest || post > 0 || opt > 0 || kw_optional
          if has_opt
            IntegerObject.new(-(req + post + req_kw_count + 1))
          else
            IntegerObject.new(req + post + req_kw_count)
          end
        end

        ANON_REST    = :__anon_rest__
        ANON_KWARGS  = :__anon_kwargs__
        ANON_BLOCK   = :__anon_block__

        def normalize_param_name(sym)
          case sym
          when ANON_REST   then :*
          when ANON_KWARGS then :**
          when ANON_BLOCK  then :&
          when /\A__repeated_\d+__\z/ then :_
          else sym
          end
        end

        def extract_method_params(m)
          # Resolve DefinedMethod to its underlying block_obj
          m = m.block_obj if m.is_a?(DefinedMethod)
          return [] unless m.respond_to?(:required_params)
          params = []
          m.required_params.each { |p| params << ArrayObject.new([SymbolObject.from(:req), SymbolObject.from(normalize_param_name(p))]) }
          m.optional_params.each { |p, _| params << ArrayObject.new([SymbolObject.from(:opt), SymbolObject.from(normalize_param_name(p))]) }
          if m.rest_param && m.rest_param != :__no_rest__
            params << ArrayObject.new([SymbolObject.from(:rest), SymbolObject.from(normalize_param_name(m.rest_param))])
          end
          m.post_params.each { |p| params << ArrayObject.new([SymbolObject.from(:req), SymbolObject.from(normalize_param_name(p))]) }
          m.required_kw_params.each { |p| params << ArrayObject.new([SymbolObject.from(:keyreq), SymbolObject.from(p)]) }
          m.optional_kw_params.each { |p, _| params << ArrayObject.new([SymbolObject.from(:key), SymbolObject.from(p)]) }
          if m.kw_rest_param == :__no_kwargs__
            params << ArrayObject.new([SymbolObject.from(:nokey)])
          elsif m.kw_rest_param
            params << ArrayObject.new([SymbolObject.from(:keyrest), SymbolObject.from(normalize_param_name(m.kw_rest_param))])
          end
          if m.block_param
            params << ArrayObject.new([SymbolObject.from(:block), SymbolObject.from(normalize_param_name(m.block_param))])
          end
          params
        end

        def bound_method_parameters(_, receiver)
          return ArrayObject.new([]) unless receiver.is_a?(BoundMethodObject)
          ArrayObject.new(extract_method_params(receiver.raw_method))
        end

        def bound_method_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          SymbolObject.from(receiver.bound_name)
        end

        def bound_method_original_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          orig = m.is_a?(Method) ? m.name : receiver.bound_name
          SymbolObject.from(orig)
        end

        def bound_method_owner(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          receiver.bound_owner
        end

        def bound_method_receiver(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          receiver.bound_receiver
        end

        def bound_method_unbind(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          UnboundMethodObject.new(receiver.raw_method, receiver.bound_name, receiver.bound_owner)
        end

        def bound_method_source_location(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          return NilObject::NIL unless m.is_a?(Method) && m.source_location
          file, line = m.source_location.split(":")
          ArrayObject.new([StringObject.new(file), IntegerObject.new(line.to_i)])
        end

        def bound_method_dup(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          BoundMethodObject.new(receiver.raw_method, receiver.bound_name, receiver.bound_receiver, receiver.bound_owner)
        end

        def bound_method_hash(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          body_id = if m.is_a?(Method)
            m.body.object_id
          elsif m.is_a?(DefinedMethod)
            m.block_obj.object_id
          else
            m.object_id
          end
          h = receiver.bound_receiver.object_id ^ body_id
          IntegerObject.new(h)
        end

        def bound_method_super(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          owner = receiver.bound_owner
          return NilObject::NIL unless owner
          super_klass = owner.is_a?(ClassObject) ? owner.superclass : nil
          return NilObject::NIL unless super_klass
          m = super_klass.lookup_method(receiver.bound_name)
          return NilObject::NIL unless m
          super_owner = super_klass.lookup_method_owner(receiver.bound_name) || super_klass
          BoundMethodObject.new(m, receiver.bound_name, receiver.bound_receiver, super_owner)
        end

        def bound_method_eql(_, m1, m2)
          return FalseObject::FALSE unless m1.is_a?(BoundMethodObject) && m2.is_a?(BoundMethodObject)
          return FalseObject::FALSE unless m1.bound_receiver.equal?(m2.bound_receiver)
          m1m = m1.raw_method; m2m = m2.raw_method
          # Methods are equal if they share the same implementation body/block
          same = if m1m.is_a?(Method) && m2m.is_a?(Method)
            m1m.equal?(m2m) || m1m.body.equal?(m2m.body)
          elsif m1m.is_a?(DefinedMethod) && m2m.is_a?(DefinedMethod)
            m1m.equal?(m2m) || m1m.block_obj.equal?(m2m.block_obj)
          else
            m1m.equal?(m2m)
          end
          same ? TrueObject::TRUE : FalseObject::FALSE
        end

        def unbound_method_parameters(_, receiver)
          return ArrayObject.new([]) unless receiver.is_a?(UnboundMethodObject)
          ArrayObject.new(extract_method_params(receiver.raw_method))
        end

        def unbound_method_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          SymbolObject.from(receiver.unbound_name)
        end

        def unbound_method_original_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          orig = m.is_a?(Method) ? m.name : receiver.unbound_name
          SymbolObject.from(orig)
        end

        def unbound_method_arity(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          return IntegerObject.new(0) unless m.is_a?(Method)
          req = m.required_params.length
          opt = m.optional_params.length
          rest = m.rest_param && m.rest_param != :__no_rest__
          post = m.post_params.length
          req_kw = m.required_kw_params.length
          opt_kw = m.optional_kw_params.length
          kw_rest = m.kw_rest_param
          req_kw_count = req_kw > 0 ? 1 : 0
          kw_optional = req_kw == 0 && (opt_kw > 0 || (kw_rest && kw_rest != :__no_kwargs__))
          has_opt = rest || post > 0 || opt > 0 || kw_optional
          if has_opt
            IntegerObject.new(-(req + post + req_kw_count + 1))
          else
            IntegerObject.new(req + post + req_kw_count)
          end
        end

        def unbound_method_source_location(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          return NilObject::NIL unless m.is_a?(Method) && m.source_location
          file, line = m.source_location.split(":")
          ArrayObject.new([StringObject.new(file), IntegerObject.new(line.to_i)])
        end

        def unbound_method_bind(_, receiver, new_receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          BoundMethodObject.new(receiver.raw_method, receiver.unbound_name, new_receiver, receiver.unbound_owner)
        end

        def unbound_method_owner(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          receiver.unbound_owner
        end

        def module_private_method_defined(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          m = receiver.get_method(name)
          m && m.visibility == :private ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_public_method_defined(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          m = receiver.get_method(name)
          m && m.visibility == :public ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_protected_method_defined(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          m = receiver.get_method(name)
          m && m.visibility == :protected ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_attr_reader(_, receiver, names)
          names.raw.each do |name_obj|
            name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
            ivar = :"@#{name}"
            body = Ast::InstanceVariableRead.new(ivar)
            m = Method.new([receiver], name, [], [], nil, [], [], [], nil, nil, [], body)
            receiver.set_method(name, m)
          end
          NilObject::NIL
        end

        def module_attr_writer(_, receiver, names)
          names.raw.each do |name_obj|
            name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
            setter = :"#{name}="
            ivar = :"@#{name}"
            body = Ast::InstanceVariableWrite.new(ivar, Ast::LocalVariableRead.new(:value, 0))
            m = Method.new([receiver], setter, [:value], [], nil, [], [], [], nil, nil, [], body)
            receiver.set_method(setter, m)
          end
          NilObject::NIL
        end

        def module_attr_accessor(context, receiver, names)
          module_attr_reader(context, receiver, names)
          module_attr_writer(context, receiver, names)
          NilObject::NIL
        end

        def module_set_public(context, receiver, names)    = module_set_visibility(context, receiver, names, :public)
        def module_set_private(context, receiver, names)   = module_set_visibility(context, receiver, names, :private)
        def module_set_protected(context, receiver, names) = module_set_visibility(context, receiver, names, :protected)

        def module_function(_, receiver, names)
          if names.is_a?(ArrayObject) && names.raw.empty?
            receiver.current_visibility = :module_function
            return receiver
          end
          name_list = names.is_a?(ArrayObject) ? names.raw : [names]
          name_list.each do |name_obj|
            name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
            m = receiver.get_method(name) || (receiver.is_a?(ClassObject) ? receiver.lookup_method(name) : nil)
            next if m.nil?
            # Add as private instance method
            m.visibility = :private
            receiver.set_method(name, m)
            # Add as public singleton method
            sm = m.dup
            sm.visibility = :public
            receiver.singleton_class.set_method(name, sm)
          end
          receiver
        end

        # Top-level 'main' proxy: delegate to Object
        def toplevel_public(context, _, names)    = module_set_visibility(context, Core::OBJECT_CLASS, names, :public)
        def toplevel_private(context, _, names)   = module_set_visibility(context, Core::OBJECT_CLASS, names, :private)
        def toplevel_protected(context, _, names) = module_set_visibility(context, Core::OBJECT_CLASS, names, :protected)

        # Kernel require/load
        def kernel_require(_, _receiver, path_obj)
          path = path_obj.raw
          # Check LOADED_FEATURES first for pre-stubbed libs (e.g. stringio, pp)
          loaded = GLOBALS[:"$LOADED_FEATURES"]
          loaded_paths = loaded.raw.map(&:raw)
          path_base = path.end_with?('.rb') ? path[0..-4] : path
          return FalseObject::FALSE if loaded_paths.any? { |p| p == path || p.end_with?("/#{path_base}") || p.end_with?("/#{path_base}.rb") }
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
          end
          TrueObject::TRUE
        end

        def kernel_integer(context, _receiver, val, base)
          return val if val.is_a?(IntegerObject)
          if val.is_a?(StringObject)
            return IntegerObject.new(Integer(val.raw, base.raw))
          end
          # Object with to_int or to_i
          if val.class_object.lookup_method(:to_int)
            return val.dispatch(context, :to_int, [], {})
          end
          val.dispatch(context, :to_i, [], {})
        end

        def kernel_float(_, _receiver, val)
          FloatObject.new(val.is_a?(FloatObject) ? val.raw : Float(val.raw))
        end

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

        def kernel_load(_, _receiver, path_obj)
          path = path_obj.raw
          full_path = File.exist?(path) ? path : resolve_load_path(path)
          if full_path.nil?
            exc = FrozoneException.make(:LoadError, "cannot load such file -- #{path}")
            exc.vm_object.set_ivar(:@path, StringObject.new(path))
            raise exc
          end
          begin
            Fiber[:vm_evaluate].call(full_path, raise_syntax_errors: true)
          rescue Ast::ReturnException
            # return at top level of loaded file stops loading gracefully
          end
          TrueObject::TRUE
        end

        def kernel_proc(context, _receiver)
          block = context.frame.block
          raise FrozoneException.make(:ArgumentError, "tried to create Proc object without a block") if block.nil?
          ProcObject.new(block)
        end

        def kernel_lambda(context, _receiver)
          block = context.frame.block
          raise FrozoneException.make(:ArgumentError, "tried to create Proc object without a block") if block.nil?
          block.make_lambda! if block.is_a?(BlockObject)
          ProcObject.new(block, lambda: true)
        end

        def proc_call(context, proc_obj, args, kw_args_obj = NilObject::NIL)
          blk = context.frame.block
          blk = nil if blk.nil? || blk.is_a?(NilObject)
          kw_args = kw_args_obj.is_a?(HashObject) ? kw_args_obj.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k } : {}
          proc_obj.call(context, args.raw, kw_args: kw_args, block: blk)
        end

        def proc_lambda_p(_context, proc_obj)
          proc_obj.lambda? ? TrueObject::TRUE : FalseObject::FALSE
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
              is_lambda: is_lambda
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
          copy = ProcObject.new(blk, lambda: proc_obj.lambda?)
          copy.class_object = proc_obj.class_object
          copy.copy_fields_from(proc_obj, eigenclass: nil, frozen: false)
          copy
        end

        def proc_clone(context, proc_obj, freeze_opt = NilObject::NIL)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          copy = ProcObject.new(blk, lambda: proc_obj.lambda?)
          copy.class_object = proc_obj.class_object
          sc_copy = proc_obj.eigenclass ? ClassObject.clone_singleton(proc_obj.eigenclass, copy) : nil
          freeze_val = freeze_opt.is_a?(NilObject) ? nil : freeze_opt.truthy?
          frozen = freeze_val == false ? false : freeze_val.nil? ? proc_obj.frozen_object? : true
          copy.copy_fields_from(proc_obj, eigenclass: sc_copy, frozen: frozen)
        end

        def proc_arity(_, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk.is_a?(NativeBlock) && blk.parameters_override
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

        def proc_parameters(_, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk.is_a?(NativeBlock) && blk.parameters_override
            return ArrayObject.new(blk.parameters_override.map { |p| ArrayObject.new(p.map { |s| SymbolObject.from(s) }) })
          end
          return ArrayObject.new([]) unless blk.is_a?(BlockObject)
          # `it` implicit parameter: return [[:req]] for lambda, [[:opt]] for proc (Ruby 4.0+)
          if blk.it_param
            is_lambda = blk.is_lambda
            return ArrayObject.new([ArrayObject.new([SymbolObject.from(is_lambda ? :req : :opt)])])
          end
          params = []
          is_lambda = blk.is_lambda
          req_type = is_lambda ? :req : :opt
          req_params = blk.required_params || []
          opt_params = blk.optional_params || []
          rest_param = blk.rest_param
          post_params = blk.post_params || []
          req_kw = blk.required_kw_params || []
          opt_kw = blk.optional_kw_params || []
          kw_rest = blk.kw_rest_param
          blk_param = blk.block_param
          req_params.each { |n| params << ArrayObject.new([SymbolObject.from(req_type), SymbolObject.from(n.is_a?(Hash) ? :* : n)]) }
          opt_params.each { |n, _| params << ArrayObject.new([SymbolObject.from(:opt), SymbolObject.from(n)]) }
          params << ArrayObject.new([SymbolObject.from(:rest), rest_param ? SymbolObject.from(rest_param) : SymbolObject.from(:*)]) if rest_param || blk.rest_param == :__implicit_rest__
          post_params.each { |n| params << ArrayObject.new([SymbolObject.from(req_type), SymbolObject.from(n)]) }
          req_kw.each { |n| params << ArrayObject.new([SymbolObject.from(:keyreq), SymbolObject.from(n)]) }
          opt_kw.each { |n, _| params << ArrayObject.new([SymbolObject.from(:key), SymbolObject.from(n)]) }
          params << ArrayObject.new([SymbolObject.from(:keyrest), kw_rest == :__no_kwargs__ ? SymbolObject.from(:nil) : SymbolObject.from(kw_rest)]) if kw_rest
          params << ArrayObject.new([SymbolObject.from(:block), SymbolObject.from(blk_param)]) if blk_param
          ArrayObject.new(params)
        end

        def proc_source_location(_, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          loc = (blk.is_a?(BlockObject) || blk.is_a?(NativeBlock)) ? blk.source_location : nil
          return NilObject::NIL unless loc
          ArrayObject.new([StringObject.new(loc[0]), IntegerObject.new(loc[1])])
        end

        def kernel_binding(context, _receiver)
          # Capture the calling frame (frames[-2] since we're inside a kernel method call).
          captured_frame = context.frames.length >= 2 ? context.frames[-2] : context.frame
          BindingObject.new(captured_frame)
        end

        def binding_local_variables(_, binding_obj)
          names = binding_obj.local_variable_names.map { |n| SymbolObject.from(n) }
          ArrayObject.new(names)
        end

        def kernel_eval(context, _receiver, code_obj, binding_arg = NilObject::NIL, filename_arg = NilObject::NIL)
          return NilObject::NIL unless code_obj.is_a?(StringObject)
          code = code_obj.raw
          eval_filename = filename_arg.is_a?(StringObject) ? filename_arg.raw : nil
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

          # IMPORTANT: pass only binding_frame.local_names to Prism (not full closure chain).
          # Passing any non-nil scope to Prism suppresses yield-in-block SyntaxErrors.
          code_enc = code.encoding != Encoding::UTF_8 ? code.encoding : nil
          # Ruby 3.4+: __FILE__ inside eval returns "(eval at file:line)" using the caller's location
          eval_filepath = eval_filename || (context.call_site ? "(eval at #{context.call_site})" : "(eval)")
          parser = Parser.new(code, outer_locals: binding_frame.local_names, encoding: code_enc, filepath: eval_filepath)
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
          # Copy locals from full closure chain into eval frame (innermost frame wins).
          # This lets eval read outer-scope variables even if not in binding_frame.local_names.
          closure_chain.reverse_each do |f|
            f.local_names.each { |name| new_frame.set_local(name, f.get_local(name)) if new_frame.local_names.include?(name) }
          end
          context.push_frame(new_frame)
          begin
            result = ast.evaluate(context)
            # Write back locals to the appropriate frame in the closure chain.
            # New eval vars go to binding_frame; existing closure vars update their original frame.
            new_frame.local_names.each do |name|
              target = closure_chain.find { |f| f.local_names.include?(name) } || binding_frame
              target.set_local(name, new_frame.get_local(name))
            end
            result
          rescue Ast::RetryException, Ast::RedoException
            raise FrozoneException.make(:SyntaxError, "Invalid #{$!.class.name.split('::').last.sub('Exception', '').downcase} in eval")
          rescue Ast::BreakException, Ast::NextException
            raise FrozoneException.make(:LocalJumpError, "unexpected #{$!.class.name.split('::').last.sub('Exception', '').downcase}")
          ensure
            context.pop_frame
          end
        end

        # Class
        def class_new(context, klass, args, kwargs, block = nil)
          raise FrozoneException.make(:TypeError, "can't create instance of singleton class") if klass.is_singleton_class
          raw_args = args.raw
          raw_kwargs = kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k }
          has_block = block && !block.is_a?(NilObject)
          if klass.equal?(Core::CLASS_CLASS)
            superclass = raw_args.first.is_a?(ClassObject) ? raw_args.first : Core::OBJECT_CLASS
            new_class = ClassObject.new(nil, nil, superclass)
            if has_block
              prev_vis = new_class.current_visibility
              new_class.current_visibility = :public
              begin
                block.invoke(context, [], receiver: new_class, def_scope: new_class)
              ensure
                new_class.current_visibility = prev_vis
              end
            end
            return new_class
          elsif klass.equal?(Core::MODULE_CLASS)
            new_mod = ModuleObject.new(nil, nil)
            if has_block
              prev_vis = new_mod.current_visibility
              new_mod.current_visibility = :public
              begin
                block.invoke(context, [], receiver: new_mod, def_scope: new_mod)
              ensure
                new_mod.current_visibility = prev_vis
              end
            end
            return new_mod
          end
          klass.new_instance(context, raw_args, raw_kwargs, block)
        end

        def subclass_of_builtin?(klass, base_class)
          k = klass
          while k.is_a?(ClassObject)
            return true if k.equal?(base_class)
            k = k.superclass
          end
          false
        end

        def class_allocate(context, klass)
          raise FrozoneException.make(:TypeError, "can't create instance of singleton class") if klass.is_singleton_class
          raise FrozoneException.make(:TypeError, "can't create instance of virtual class") if klass.equal?(Core::CLASS_CLASS) || klass.equal?(Core::MODULE_CLASS)
          klass.allocate_instance
        end

        def class_superclass(_, klass)
          sc = klass.is_a?(ClassObject) ? klass.superclass : nil
          sc.nil? ? NilObject::NIL : sc
        end

        def bool_object_for(bool) = bool ? TrueObject::TRUE : FalseObject::FALSE

        private

        def normalize_ivar(name)
          sym = name.is_a?(SymbolObject) ? name.raw : name.raw.to_sym
          :"@#{sym.to_s.delete_prefix('@')}"
        end

        def collect_method_names(v, include_super, &visibility_ok)
          seen = {}
          result = []
          sources = []
          sources << v.singleton_class if v.eigenclass
          if include_super
            # For ClassObjects, also walk superclass eigenclasses (class methods of superclasses)
            if v.is_a?(ClassObject) && v.respond_to?(:superclass)
              c = v.respond_to?(:superclass) ? v.superclass : nil
              while c
                sources << c.eigenclass if c.eigenclass
                c = c.respond_to?(:superclass) ? c.superclass : nil
              end
            end
            c = v.class_object
            while c
              sources << c
              c.modules.reverse_each { |m| sources << m }
              c = c.is_a?(ClassObject) ? c.superclass : nil
            end
          else
            sources << v.class_object
          end
          sources.each do |mod|
            mod.methods_table.each do |name, meth|
              next if seen[name]
              seen[name] = true
              next if meth == ModuleObject::UNDEF_SENTINEL
              next unless visibility_ok.call(meth.visibility)
              result << SymbolObject.from(name)
            end
          end
          ArrayObject.new(result)
        end

        def module_set_visibility(_, receiver, names, vis)
          if names.raw.empty?
            receiver.current_visibility = vis
          else
            names.raw.each do |name_obj|
              name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
              m = receiver.get_method(name)
              if m.nil?
                m = receiver.lookup_method(name)
                next if m.nil?
                # Duplicate the method so we don't change visibility on the superclass's copy
                m = m.dup_with_visibility(vis)
                receiver.set_method(name, m)
              else
                m.visibility = vis
              end
            end
          end
          NilObject::NIL
        end

        def resolve_load_path(path)
          path_rb = path.end_with?('.rb') ? path : "#{path}.rb"
          return path_rb if File.exist?(path_rb)
          load_path = GLOBALS[:"$LOAD_PATH"]
          load_path&.raw&.each do |dir_obj|
            full = File.join(dir_obj.raw, path_rb)
            return full if File.exist?(full)
          end
          nil
        end

      end
    end
  end
end

require_relative 'intrinsics/numeric_intrinsics'
require_relative 'intrinsics/io_intrinsics'
require_relative 'intrinsics/string_intrinsics'
require_relative 'intrinsics/collection_intrinsics'
