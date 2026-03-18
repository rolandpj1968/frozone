module Frozone
  module Vm
    module Intrinsics
      # Current Frozone (simulated) thread ID: nil = main thread, otherwise the
      # object_id of the active Frozone Thread object (set by thread_save_reset_locals).
      # Single-element array so it can be mutated from class methods.
      CURRENT_FROZONE_THREAD_ID = [nil]

      class << self
        # Object
        def object_class(_, v) = v.class_object

        def object_class_name(_, v)
          StringObject.new(frozone_class_name(v))
        end

        def object_is_a(_, v, klass)
          # Metaclass hierarchy: #<Class:Foo>.is_a?(#<Class:Bar>) iff Foo.is_a?(Bar's underlying class)
          if v.is_a?(ClassObject) && v.is_singleton_class &&
             klass.is_a?(ClassObject) && klass.is_singleton_class
            sc_of_v = v.singleton_of
            sc_of_k = klass.singleton_of
            if sc_of_v.is_a?(ClassObject) && sc_of_k.is_a?(ClassObject)
              return object_is_a(nil, sc_of_v, sc_of_k)
            end
            # Instance singleton class is_a? class's singleton class iff instance's class <= that class.
            # e.g. instance.singleton_class.is_a?(klass.singleton_class) iff instance.class <= klass
            if !sc_of_v.is_a?(ClassObject) && sc_of_k.is_a?(ClassObject)
              # Check if instance's class is sc_of_k or a subclass of it (walk superclass chain)
              c2 = sc_of_v.class_object
              until c2.nil?
                return TrueObject::TRUE if c2.ancestors_include?(sc_of_k)
                c2 = c2.is_a?(ClassObject) ? c2.superclass : nil
              end
              return FalseObject::FALSE
            end
          end
          # A non-singleton class is_a? a singleton class iff the class <= singleton class's singleton_of.
          # e.g. b.is_a?(a.singleton_class) iff b <= a (b is a or a subclass of a).
          if v.is_a?(ClassObject) && !v.is_singleton_class &&
             klass.is_a?(ClassObject) && klass.is_singleton_class
            sc_of_k = klass.singleton_of
            if sc_of_k.is_a?(ClassObject)
              c2 = v
              until c2.nil?
                return TrueObject::TRUE if c2.ancestors_include?(sc_of_k)
                c2 = c2.is_a?(ClassObject) ? c2.superclass : nil
              end
              return FalseObject::FALSE
            end
          end
          # Walk from lookup_class (eigenclass if materialised, else class_object).
          # ancestors_include? short-circuits and handles transitive prepend/include at each level.
          c = v.lookup_class
          until c.nil?
            return TrueObject::TRUE if c.ancestors_include?(klass)
            c = c.is_a?(ClassObject) ? c.superclass : nil
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
          if v.frozen_object?
            type_name = frozone_class_name(v)
            raise FrozoneException.make(:FrozenError, "can't modify frozen #{type_name}: #{v.inspect rescue v.object_id}")
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
          method_name = name.is_a?(SymbolObject) ? name.raw : (name.is_a?(StringObject) ? name.raw.to_sym : name.raw)
          # Check active refinements first (refinements can add methods visible to respond_to?)
          active_refinements = context&.frame&.active_refinements
          m = if active_refinements && !active_refinements.empty?
            v.lookup_method_with_refinements(method_name, active_refinements)
          else
            v.lookup_instance_method(method_name)
          end
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

        def object_private_methods(_, v, include_super_obj = TrueObject::TRUE)
          collect_method_names(v, include_super_obj.truthy?) { |vis| vis == :private }
        end

        def object_protected_methods(_, v, include_super_obj = TrueObject::TRUE)
          collect_method_names(v, include_super_obj.truthy?) { |vis| vis == :protected }
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

        def module_dup(context, v)
          # BasicObject cannot be duped
          raise FrozoneException.make(:TypeError, "can't copy the root class") if v.equal?(Core::BASIC_OBJECT_CLASS)
          # Create a fresh anonymous module/class and copy the source's contents.
          copy = if v.is_a?(ClassObject)
                   ClassObject.new(nil, v.namespace, v.superclass)
                 else
                   ModuleObject.new(nil, v.namespace, Core::MODULE_CLASS)
                 end
          # Copy methods table (shallow: same Method objects, they're immutable enough)
          v.methods_table.each { |k, meth| copy.methods_table[k] = meth }
          # Copy class variables
          v.class_variables.each { |k, val| copy.class_variables[k] = val }
          # Copy constants
          v.constants_table.each { |k, val| copy.set_constant(k, val) }
          # Copy private-constants set
          v.private_constants_table&.each_key { |k| copy.mark_constant_private(k) }
          # Copy autoload registrations
          v.instance_variable_get(:@autoloads).each do |name, path|
            loc = v.get_autoload_location(name)
            copy.set_autoload(name, path, source_location: loc)
          end
          # Copy prepended/included modules references
          v.prepends.each { |m| copy.prepend_module(m) }
          v.modules.each  { |m| copy.add_module(m) }
          # Copy singleton class (for module/class methods like `def mod.foo`)
          if v.eigenclass
            sc_copy = ClassObject.clone_singleton(v.eigenclass, copy)
            copy.instance_variable_set(:@eigenclass, sc_copy)
          end
          # Call initialize_copy for instance variables
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
          str_val = if str_arg.is_a?(StringObject)
                      str_arg.raw
                    else
                      begin
                        r = str_arg.dispatch(context, :to_str, [], {})
                        raise FrozoneException.make(:TypeError, "no implicit conversion of #{str_arg.class_object&.name} into String") unless r.is_a?(StringObject)
                        r.raw
                      rescue FrozoneException => e
                        vm_obj = e.vm_object
                        if vm_obj.is_a?(ObjectObject) && vm_obj.class_object&.name == :NoMethodError
                          raise FrozoneException.make(:TypeError, "no implicit conversion of #{str_arg.class_object&.name} into String")
                        end
                        raise
                      end
                    end
          receiver.raw = str_val.dup
          NilObject::NIL
        end

        def string_clone(context, v, freeze_opt = NilObject::NIL)
          copy = StringObject.new(v.raw.dup)
          copy.class_object = v.class_object
          sc_copy = v.eigenclass ? ClassObject.clone_singleton(v.eigenclass, copy) : nil
          freeze_val = freeze_opt.is_a?(NilObject) ? nil : freeze_opt.truthy?
          frozen = freeze_val == false ? false : freeze_val.nil? ? v.frozen_object? : true
          copy.copy_fields_from(v, eigenclass: sc_copy, frozen: frozen)
          copy.chilled_source = v.chilled_source unless frozen  # clone preserves chilled status
          copy.dispatch(context, :initialize_copy, [v], {}, nil, private_ok: true)
          copy
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

        def object_singleton_class(context, v)
          # Integer and Symbol don't have singleton classes
          if v.is_a?(IntegerObject) || v.is_a?(SymbolObject)
            raise FrozoneException.make(:TypeError, "can't define singleton for #{v.class_object.name}")
          end
          # true/false/nil return their class (they are singleton instances)
          if v.is_a?(TrueObject) || v.is_a?(FalseObject) || v.is_a?(NilObject)
            return v.class_object
          end
          if v.is_a?(StringObject) && v.chilled?
            Frozone::Vm.emit_warning(context, v.chilled_warning)
            v.unchilled!
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

        def io_popen_capture(_, cmd, opts_obj = NilObject::NIL)
          # Convert opts HashObject to MRI hash
          mri_opts = {}
          if opts_obj.is_a?(HashObject) && !opts_obj.raw.empty?
            opts_obj.raw.each do |k, v|
              key = k.is_a?(SymbolObject) ? k.raw : k.raw.to_sym
              val = case v
                    when ArrayObject then v.raw.map { |e| e.is_a?(SymbolObject) ? e.raw : e.raw }
                    when SymbolObject then v.raw
                    when IntegerObject then v.raw
                    else v.raw
                    end
              mri_opts[key] = val
            end
          end

          output = if cmd.is_a?(ArrayObject)
            cmd_arr = cmd.raw.map { |a| a.is_a?(StringObject) ? a.raw : a.to_s }
            ::IO.popen(cmd_arr, 'r', **mri_opts, &:read) rescue ""
          elsif cmd.is_a?(StringObject)
            ::IO.popen(cmd.raw, 'r', **mri_opts, &:read) rescue ""
          else
            ::IO.popen(cmd.to_s, 'r', **mri_opts, &:read) rescue ""
          end
          GLOBALS[:"$?"] = ProcessStatusObject.new($?) if $?
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

        def kernel_caller_locations(context, _receiver, start_obj = NilObject::NIL, length_obj = NilObject::NIL)
          start  = start_obj.is_a?(IntegerObject)  ? start_obj.raw : 1
          length = length_obj.is_a?(IntegerObject) ? length_obj.raw : nil

          all_frames = context.frames.reverse
          last_caller_idx = all_frames.rindex { |f| f.current_method&.name == :caller_locations } || -1
          base = [last_caller_idx, 0].max

          location_class = Core::OBJECT_CLASS.get_constant(:Thread)&.get_constant(:Backtrace)&.get_constant(:Location)
          entries = []
          i = base
          while i < all_frames.length - 1
            call_site = all_frames[i].incoming_call_site || "unknown:0"
            meth = all_frames[i + 1].current_method&.name&.to_s || "block"
            str_obj = StringObject.new("#{call_site}:in '#{meth}'", frozen: true)
            if location_class
              loc_obj = location_class.dispatch(context, :_from_string, [str_obj], {}, nil, private_ok: true)
              entries << loc_obj
            else
              entries << str_obj
            end
            i += 1
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

        # Build a FrozoneException from raise args without actually raising it.
        NO_ARG_SENTINEL = SymbolObject.from(:__raise_no_arg__)

        def build_frozone_exception(context, args)
          begin
            args_spread = args.is_a?(ArrayObject) ? args.raw : Array(args)
            # Pass sentinel for empty args so kernel_raise treats it as bare re-raise
            first_arg = args_spread.empty? ? NO_ARG_SENTINEL : args_spread[0]
            kernel_raise(context, NilObject::NIL, first_arg, *args_spread[1..])
            FrozoneException.make(:RuntimeError, "")  # fallback
          rescue FrozoneException => e
            e
          end
        end

        def exception_instance?(obj)
          frozone_exc_class = Core::OBJECT_CLASS.get_constant(:Exception)
          return false unless frozone_exc_class && obj.is_a?(ObjectObject)
          c = obj.class_object
          while c
            return true if c.equal?(frozone_exc_class)
            c = c.respond_to?(:superclass) ? c.superclass : nil
          end
          false
        end

        def validate_cause(cause, exc_obj)
          return if cause.nil?
          # cause must be an Exception instance or NilObject (nil)
          raise FrozoneException.make(:TypeError, "exception object expected") unless exception_instance?(cause)
          # self-cause: don't set if cause equals exc_obj
          return if exc_obj && cause.equal?(exc_obj)
          # circular cause check: walk cause chain looking for exc_obj
          if exc_obj && exc_obj.is_a?(ObjectObject)
            c = cause
            while c && exception_instance?(c)
              c_cause = c.get_ivar(:@cause)
              break if c_cause.nil? || c_cause.is_a?(NilObject)
              if c_cause.equal?(exc_obj)
                raise FrozoneException.make(:ArgumentError, "circular causes")
              end
              c = c_cause
            end
          end
        end

        def apply_backtrace(exc_obj, backtrace_arg, context)
          if backtrace_arg.is_a?(ArrayObject)
            exc_obj.set_ivar(:@backtrace, backtrace_arg)
            # Detect if elements are Thread::Backtrace::Location objects (not plain strings)
            first = backtrace_arg.raw.first
            has_locs = first.is_a?(ObjectObject) && !first.is_a?(StringObject)
            exc_obj.set_ivar(:@_has_locations, has_locs ? TrueObject::TRUE : FalseObject::FALSE)
          elsif !backtrace_arg.nil? && !backtrace_arg.is_a?(NilObject)
            exc_obj.set_ivar(:@backtrace, backtrace_arg)
            exc_obj.set_ivar(:@_has_locations, TrueObject::TRUE)
          else
            set_exc_backtrace(exc_obj, context)
          end
        end

        def kernel_raise(context, _receiver, msg = NilObject::NIL, message_arg = nil, backtrace_arg = nil, cause_arg = nil)
          current_exc = GLOBALS[:"$!"]
          no_cause_sentinel = cause_arg.is_a?(SymbolObject) && cause_arg.raw == :__raise_no_cause__
          explicit_cause = !cause_arg.nil? && !no_cause_sentinel

          # Distinguish bare `raise` (no args → :__raise_no_arg__ sentinel) from `raise(nil)` (explicit nil → TypeError)
          no_arg_sentinel = msg.is_a?(SymbolObject) && msg.raw == :__raise_no_arg__

          # ArgumentError: only cause: given with no positional args
          if no_arg_sentinel && explicit_cause
            raise FrozoneException.make(:ArgumentError, "only cause is given with no arguments")
          end

          # Validate explicit cause type before building exception
          if explicit_cause && !cause_arg.is_a?(NilObject)
            raise FrozoneException.make(:TypeError, "exception object expected") unless exception_instance?(cause_arg)
          end

          cause = if no_cause_sentinel
            (current_exc && !current_exc.is_a?(NilObject)) ? current_exc : nil
          elsif cause_arg.nil? || cause_arg.is_a?(NilObject)
            nil
          else
            cause_arg
          end

          if no_arg_sentinel
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
            exc_obj = if message_arg && !message_arg.is_a?(NilObject)
              msg.dispatch(context, :exception, [message_arg], {})
            else
              msg.dispatch(context, :exception, [], {})
            end
            msg_str = begin
              exc_obj.dispatch(context, :message, [], {}).raw
            rescue StandardError
              msg.name.to_s
            end
            effective_cause = (cause && !cause.equal?(exc_obj)) ? cause : nil
            validate_cause(effective_cause, exc_obj)
            exc_obj.set_ivar(:@cause, effective_cause) if effective_cause
            apply_backtrace(exc_obj, backtrace_arg, context)
            raise FrozoneException.new(exc_obj, msg_str)
          elsif msg.is_a?(StringObject) && (message_arg.nil? || message_arg.is_a?(NilObject))
            # raise "message" — create RuntimeError with string
            exc = FrozoneException.make(:RuntimeError, msg.raw)
            effective_cause = (cause && !cause.equal?(exc.vm_object)) ? cause : nil
            exc.vm_object.set_ivar(:@cause, effective_cause) if effective_cause
            apply_backtrace(exc.vm_object, backtrace_arg, context)
            raise exc
          else
            # raise exception_object — first check if it responds to #exception
            # (this implements the exception protocol: any object with #exception can be raised)
            has_message_arg = !message_arg.nil? && !message_arg.is_a?(NilObject)
            exc_obj = begin
              msg.dispatch(context, :exception, has_message_arg ? [message_arg] : [], {})
            rescue FrozoneException => nm_err
              # NoMethodError or similar — try using msg directly if it's Exception subclass
              is_exc = exception_instance?(msg)
              is_exc ? msg : (raise FrozoneException.make(:TypeError, "exception class/object expected"))
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
            already_has_bt = exc_obj.is_a?(ObjectObject) && exc_obj.get_ivar(:@backtrace).is_a?(ArrayObject)
            unless already_has_bt
              apply_backtrace(exc_obj, backtrace_arg, context)
            end
            raise FrozoneException.new(exc_obj, msg_str)
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

        def kernel__method__(context, _receiver)
          frames = context.frames
          # Walk up frames to find the nearest method frame (skip block/proc frames)
          (frames.length - 2).downto(0) do |i|
            m = frames[i].current_method
            return m.is_a?(Method) ? SymbolObject.from(m.name) : NilObject::NIL if m
          end
          NilObject::NIL
        end

        CALLEE_TRANSPARENT_METHODS = %i[send __send__ public_send].freeze

        def kernel__callee__(context, _receiver)
          # __callee__ returns the callee name of the innermost non-transparent method frame.
          # send/__send__/public_send are transparent: skip them and look at the calling method.
          frames = context.frames
          i = frames.length - 2
          while i >= 0
            mf = frames[i].method_frame
            return NilObject::NIL unless mf
            cn = mf.callee_name
            break unless cn && CALLEE_TRANSPARENT_METHODS.include?(cn)
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

        def process_status_termsig(_, obj)
          sig = obj.native_status.termsig
          sig ? IntegerObject.new(sig) : NilObject::NIL
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

        def kernel_rand(context, _receiver, n)
          random_rand(context, nil, n)
        end

        def kernel_srand(_, _receiver, seed)
          result = seed.nil? || seed.is_a?(NilObject) ? srand : srand(seed.raw)
          IntegerObject.new(result)
        end

        def random_new(context, _receiver, seed)
          if seed.nil? || seed.is_a?(NilObject)
            raw_seed = nil
          elsif seed.is_a?(IntegerObject)
            raw_seed = seed.raw
          elsif seed.respond_to?(:raw)
            raw_seed = seed.raw
            if raw_seed.is_a?(::Rational)
              raw_seed = raw_seed.to_i
            elsif raw_seed.is_a?(::Complex)
              if raw_seed.imaginary != 0
                raise FrozoneException.make(:RangeError, "can't convert #{raw_seed.inspect} into Integer")
              end
              raw_seed = raw_seed.real.to_i
            elsif raw_seed.respond_to?(:to_i)
              raw_seed = raw_seed.to_i
            end
          elsif seed.is_a?(ObjectObject) && seed.class_object&.name == :Complex
            imag = seed.dispatch(context, :imaginary, [], {})
            imag_raw = imag.is_a?(IntegerObject) ? imag.raw : (imag.respond_to?(:raw) ? imag.raw : 0)
            if imag_raw != 0
              raise FrozoneException.make(:RangeError, "can't convert #{seed.class_object.name}(#{imag_raw}i) into Integer")
            end
            real_obj = seed.dispatch(context, :real, [], {})
            int_obj = real_obj.dispatch(context, :to_i, [], {})
            raw_seed = int_obj.is_a?(IntegerObject) ? int_obj.raw : int_obj.raw.to_i
          elsif seed.is_a?(ObjectObject) && seed.class_object&.name == :Rational
            int_obj = seed.dispatch(context, :to_i, [], {})
            raw_seed = int_obj.is_a?(IntegerObject) ? int_obj.raw : int_obj.raw.to_i
          else
            begin
              result = seed.dispatch(context, :to_int, [], {})
              raw_seed = result.is_a?(IntegerObject) ? result.raw : result.raw.to_i
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              klass = seed.respond_to?(:class_object) ? (seed.class_object&.name || seed.class) : seed.class
              raise FrozoneException.make(:TypeError, "can't convert #{klass} into Integer")
            end
          end
          RandomObject.new(raw_seed)
        end

        def random_rand(context, v, n)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          if n.nil? || n.is_a?(NilObject)
            FloatObject.new(rng.rand)
          elsif n.is_a?(IntegerObject)
            IntegerObject.new(rng.rand(n.raw))
          elsif n.is_a?(FloatObject)
            FloatObject.new(rng.rand(n.raw))
          elsif n.is_a?(RangeObject)
            beg_val = n.begin_val
            end_val = n.end_val
            # If begin/end are native types, delegate to MRI rand
            if (beg_val.is_a?(IntegerObject) || beg_val.is_a?(FloatObject) ||
                beg_val.nil? || beg_val.is_a?(NilObject)) &&
               (end_val.is_a?(IntegerObject) || end_val.is_a?(FloatObject) ||
                end_val.nil? || end_val.is_a?(NilObject))
              result = rng.rand(n.raw)
              result.is_a?(Integer) ? IntegerObject.new(result) : FloatObject.new(result)
            else
              # Custom object range: compute beg + rand*(end-beg)
              begin
                diff = end_val.dispatch(context, :-, [beg_val], {})
              rescue FrozoneException => e
                raise FrozoneException.make(:ArgumentError, "bad value for range") unless e.frozone_class_name == :ArgumentError
                raise
              end
              # Try integer path first (to_int)
              int_diff = begin
                diff.dispatch(context, :to_int, [], {})
              rescue FrozoneException
                nil
              end
              if int_diff&.is_a?(IntegerObject)
                size = int_diff.raw
                size -= 1 if n.exclusive? && size > 0
                rand_int = rng.rand(size + 1)
                beg_val.dispatch(context, :+, [IntegerObject.new(rand_int)], {})
              else
                # Float path
                float_diff = begin
                  diff.dispatch(context, :to_f, [], {})
                rescue FrozoneException
                  diff
                end
                diff_f = float_diff.is_a?(FloatObject) ? float_diff.raw : 1.0
                rand_f = rng.rand * diff_f
                beg_val.dispatch(context, :+, [FloatObject.new(rand_f)], {})
              end
            end
          else
            # Try to_int coercion
            begin
              result = n.dispatch(context, :to_int, [], {})
              IntegerObject.new(rng.rand(result.is_a?(IntegerObject) ? result.raw : result.raw.to_i))
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              klass = n.respond_to?(:class_object) ? (n.class_object&.name || n.class) : n.class
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Integer")
            end
          end
        end

        def random_seed(_, v)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          IntegerObject.new(rng.seed)
        end

        def random_new_seed(_, _receiver)
          IntegerObject.new(Random.new_seed)
        end

        def random_bytes(_, v, n_obj)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          n = n_obj.is_a?(IntegerObject) ? n_obj.raw : n_obj.raw.to_i
          StringObject.new(rng.bytes(n))
        end

        def random_urandom(_, _v, n_obj)
          n = n_obj.is_a?(IntegerObject) ? n_obj.raw : n_obj.raw.to_i
          StringObject.new(Random.urandom(n))
        end

        def random_state(_, v)
          rng = v.is_a?(RandomObject) ? v.rng : Random
          state_val = begin
            rng.send(:state)
          rescue
            rng.seed
          end
          IntegerObject.new(state_val)
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

        def send_method_name(name)
          if name.is_a?(SymbolObject)
            name.raw
          elsif name.is_a?(StringObject)
            name.raw.to_sym
          else
            klass = name.respond_to?(:class_object) ? (name.class_object&.name || name.class) : name.class
            raise FrozoneException.make(:TypeError, "#{klass} is not a symbol nor a string")
          end
        end

        def basic_object___send__(context, receiver, name, args, kwargs, block_arg = nil)
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

        def object_public_send(context, receiver, name, args, kwargs, block_arg = nil)
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

        # Module
        def module_include(_, receiver, mod)
          receiver.add_module(mod)
          receiver
        end

        # Multi-module include: calls append_features + included hook for each module (reversed).
        def module_include_multi(context, receiver, mods_obj)
          raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given 0, expected 1+)") if mods_obj.raw.empty?
          mods_obj.raw.reverse_each do |mod|
            # Must be a Module but not a Class (MRI allows Module subclass instances)
            is_module = mod.is_a?(ModuleObject) || object_is_a(nil, mod, Core::MODULE_CLASS).truthy?
            is_class  = mod.is_a?(ClassObject)  || object_is_a(nil, mod, Core::CLASS_CLASS).truthy?
            if !is_module || is_class
              type = frozone_class_name(mod)
              raise FrozoneException.make(:TypeError, "wrong argument type #{type} (expected Module)")
            end
            # Refinement modules cannot be included
            if mod.is_a?(ModuleObject) && mod.get_ivar(:@__refinement__)&.truthy?
              raise FrozoneException.make(:TypeError, "Cannot include refinement")
            end
            mod.dispatch(context, :append_features, [receiver], {}, nil, private_ok: true)
            begin
              mod.dispatch(context, :included, [receiver], {}, nil, private_ok: true)
            rescue FrozoneException
              # ignore if not defined (shouldn't happen since Module defines it)
            end
          end
          receiver
        end

        # Multi-module prepend: calls prepend_features + prepended hook for each module (reversed).
        def module_prepend_multi(context, receiver, mods_obj)
          raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given 0, expected 1+)") if mods_obj.raw.empty?
          mods_obj.raw.reverse_each do |mod|
            is_module = mod.is_a?(ModuleObject) || object_is_a(nil, mod, Core::MODULE_CLASS).truthy?
            is_class  = mod.is_a?(ClassObject)  || object_is_a(nil, mod, Core::CLASS_CLASS).truthy?
            if !is_module || is_class
              type = frozone_class_name(mod)
              raise FrozoneException.make(:TypeError, "wrong argument type #{type} (expected Module)")
            end
            # Refinement modules cannot be prepended
            if mod.is_a?(ModuleObject) && mod.get_ivar(:@__refinement__)&.truthy?
              raise FrozoneException.make(:TypeError, "Cannot prepend refinement")
            end
            mod.dispatch(context, :prepend_features, [receiver], {}, nil, private_ok: true)
            begin
              mod.dispatch(context, :prepended, [receiver], {}, nil, private_ok: true)
            rescue FrozoneException
              # ignore if not defined
            end
          end
          receiver
        end

        # Default implementation of Module#append_features — adds self to other's ancestor chain.
        def module_append_features(_, self_mod, other)
          raise FrozoneException.make(:TypeError, "append_features is not permitted on classes") if self_mod.is_a?(ClassObject)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(other)} (expected Module)") unless other.is_a?(ModuleObject)
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{frozone_class_name(other)}: #{other.full_name || other.object_id}") if other.frozen_object?
          # Cyclic include check
          if other.equal?(self_mod) || (self_mod.respond_to?(:ancestors_list) && self_mod.ancestors_list.any? { |a| a.equal?(other) })
            raise FrozoneException.make(:ArgumentError, "cyclic include detected")
          end
          other.add_module(self_mod)
          other
        end

        # Default implementation of Module#prepend_features — adds self to other's prepend chain.
        def module_prepend_features(_, self_mod, other)
          raise FrozoneException.make(:TypeError, "prepend_features is not permitted on classes") if self_mod.is_a?(ClassObject)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(other)} (expected Module)") unless other.is_a?(ModuleObject)
          # Cyclic prepend check
          if other.equal?(self_mod) || (self_mod.respond_to?(:ancestors_list) && self_mod.ancestors_list.any? { |a| a.equal?(other) })
            raise FrozoneException.make(:ArgumentError, "cyclic prepend detected")
          end
          other.prepend_module(self_mod)
          other
        end

        def frozone_class_name(obj)
          obj.is_a?(ObjectObject) ? (obj.class_object&.name || "Object") : obj.class.name
        end

        # Get active refinements from the calling context. When a method lookup intrinsic
        # (respond_to?, method, instance_method, etc.) is called from within a Frozone method,
        # context.frame is the method's own frame (typically no refinements), and
        # context.frame.parent_frame is the actual call-site frame with the caller's refinements.
        # We check both the current frame and its parent to find any active refinements.
        def caller_active_refinements(context)
          refs = context&.frame&.active_refinements
          return refs if refs && !refs.empty?
          context&.frame&.parent_frame&.active_refinements
        end

        def toplevel_include(_, _self, mods)
          target = Fiber[:load_wrap_module] || Core::OBJECT_CLASS
          mods.raw.each { |mod| target.add_module(mod) }
          target
        end

        def module_prepend(_, receiver, mod)
          receiver.prepend_module(mod)
          receiver
        end

        def object_instance_eval(context, receiver, block)
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          # Pass receiver as block arg so |obj| parameters receive self (MRI behaviour)
          return block.invoke(context, [receiver], receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(ProcObject)
          return block.invoke(context, [receiver], receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(BlockObject)
          NilObject::NIL
        end

        def object_instance_eval_string(context, receiver, code_obj, file_obj = NilObject::NIL, line_obj = NilObject::NIL)
          # Coerce code to String via to_str
          code = if code_obj.is_a?(StringObject)
            code_obj.raw
          else
            klass = code_obj.respond_to?(:class_object) ? (code_obj.class_object&.name || code_obj.class) : code_obj.class
            begin
              result = code_obj.dispatch(context, :to_str, [], {})
              raise FrozoneException.make(:TypeError, "can't convert #{klass} into String") unless result.is_a?(StringObject)
              result.raw
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
            end
          end
          # Coerce filename via to_str
          fname = if file_obj.is_a?(StringObject)
            file_obj.raw
          elsif !file_obj.is_a?(NilObject)
            klass = file_obj.respond_to?(:class_object) ? (file_obj.class_object&.name || file_obj.class) : file_obj.class
            begin
              result = file_obj.dispatch(context, :to_str, [], {})
              raise FrozoneException.make(:TypeError, "can't convert #{klass} into String") unless result.is_a?(StringObject)
              result.raw
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into String")
            end
          end
          # Coerce line number via to_int
          lnum = if line_obj.is_a?(IntegerObject)
            line_obj.raw
          elsif !line_obj.is_a?(NilObject)
            klass = line_obj.respond_to?(:class_object) ? (line_obj.class_object&.name || line_obj.class) : line_obj.class
            begin
              result = line_obj.dispatch(context, :to_int, [], {})
              raise FrozoneException.make(:TypeError, "can't convert #{klass} into Integer") unless result.is_a?(IntegerObject)
              result.raw
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
              raise FrozoneException.make(:TypeError, "no implicit conversion of #{klass} into Integer")
            end
          else
            1
          end
          # Default filepath: "(eval at caller:line)"
          # The current frame is instance_eval's own method frame; the caller is one level up.
          caller_frame = context.frames[-2] || context.frame
          eval_filepath = fname || (context.call_site ? "(eval at #{context.call_site})" : "(eval)")
          # Get caller's locals so eval code can access/modify them
          caller_local_names = caller_frame.local_names
          parser = Parser.new(code, filepath: eval_filepath, line: lnum, outer_locals: caller_local_names)
          ast = parser.ast
          # Seed the eval frame with the caller's current local variable values so that
          # reads in the eval see the caller's values, and after the eval we write them back.
          eval_locals = parser.top_level_locals
          # Constant lookup order: receiver singleton, receiver class, then caller scopes
          # (receiver class hierarchy searched via step 2 of ModuleObject.lookup_constant)
          receiver_sc = receiver.singleton_class
          receiver_class = receiver.is_a?(ModuleObject) ? receiver : receiver.class_object
          eval_scopes = caller_frame.scopes + [receiver_class, receiver_sc]
          new_frame = Frame.new(receiver, eval_locals, eval_scopes)
          caller_local_names.each do |name|
            next unless eval_locals.include?(name)
            v = caller_frame.get_local(name)
            new_frame.set_local(name, v) if v
          end
          new_frame.parent_frame = caller_frame
          new_frame.method_frame = new_frame
          # `def` inside instance_eval always targets receiver's singleton class
          new_frame.def_scope = receiver.singleton_class
          # Class variable lookup uses caller's lexical scope (not receiver's singleton)
          caller_mf = caller_frame.method_frame
          new_frame.cvar_scope = caller_mf&.cvar_scope || caller_mf&.def_scope
          context.push_frame(new_frame)
          begin
            result = ast.evaluate(context)
            # Write back any caller locals that were modified in the eval frame
            caller_local_names.each do |name|
              next unless eval_locals.include?(name)
              caller_frame.set_local(name, new_frame.get_local(name))
            end
            result
          ensure
            context.pop_frame
          end
        end

        def object_instance_exec(context, receiver, args, block)
          if block.nil? || block.is_a?(NilObject)
            raise FrozoneException.make(:LocalJumpError, "no block given")
          end
          return block.invoke(context, args.raw, receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(ProcObject)
          return block.invoke(context, args.raw, receiver: receiver, instance_eval_receiver: receiver) if block.is_a?(BlockObject)
          NilObject::NIL
        end

        def object_extend(context, receiver, mod)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(mod)} (expected Module)") unless mod.is_a?(ModuleObject)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(mod)} (expected Module)") if mod.is_a?(ClassObject)
          # Refinement modules cannot be used with Object#extend
          if mod.is_a?(ModuleObject) && mod.get_ivar(:@__refinement__)&.truthy?
            raise FrozoneException.make(:TypeError, "Refinement#extend_object has been removed")
          end
          mod.dispatch(context, :extend_object, [receiver], {}, nil, private_ok: true)
          begin
            mod.dispatch(context, :extended, [receiver], {}, nil, private_ok: true)
          rescue FrozoneException
            # ignore if not defined
          end
          receiver
        end

        def module_extend_object(_, self_mod, obj)
          raise FrozoneException.make(:TypeError, "extend_object is not permitted on classes") if self_mod.is_a?(ClassObject)
          raise FrozoneException.make(:RuntimeError, "can't modify frozen #{frozone_class_name(obj)}: #{obj.object_id}") if obj.frozen_object?
          obj.singleton_class.add_module(self_mod)
          obj
        end

        def module_deprecate_constant(_, receiver, names_obj)
          names = names_obj.is_a?(ArrayObject) ? names_obj.raw : [names_obj]
          names.each do |name_obj|
            name = sym_name(name_obj)
            val, = receiver.lookup_constant_with_owner(name)
            raise FrozoneException.make(:NameError, "constant #{receiver.full_name}::#{name} not defined") if val.nil?
            receiver.instance_variable_get(:@deprecated_constants) ||
              receiver.instance_variable_set(:@deprecated_constants, {})
            receiver.instance_variable_get(:@deprecated_constants)[name] = true
          end
          receiver
        end

        def maybe_warn_deprecated_constant(context, owner, name)
          return unless owner.is_a?(ModuleObject)
          deprecated = owner.instance_variable_get(:@deprecated_constants)
          return unless deprecated&.key?(name)
          return unless deprecated_warnings_enabled?
          mod_name = owner.full_name || "<anonymous>"
          Frozone::Vm.emit_warning(context, "constant #{mod_name}::#{name} is deprecated")
        end

        # Thread-local global isolation: save $_ and $? before running Thread body.
        THREAD_SAVED_LOCALS = {}

        def thread_save_reset_locals(_, thread_obj)
          THREAD_SAVED_LOCALS[thread_obj.object_id] = {
            dollar_underscore: GLOBALS.fetch(:"$_", NilObject::NIL),
            dollar_question:   GLOBALS.fetch(:"$?", NilObject::NIL),
            frozone_thread_id: CURRENT_FROZONE_THREAD_ID[0]
          }
          GLOBALS[:"$_"] = NilObject::NIL
          GLOBALS.delete(:"$?")
          CURRENT_FROZONE_THREAD_ID[0] = thread_obj.object_id
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
          CURRENT_FROZONE_THREAD_ID[0] = saved.key?(:frozone_thread_id) ? saved[:frozone_thread_id] : nil
          NilObject::NIL
        end

        def thread_run_block(context, block_obj)
          bo = block_obj.is_a?(ProcObject) ? block_obj.block_object : block_obj
          bo.invoke(context, [], thread_boundary: true)
        end

        def fiber_new(_, klass, block_obj, blocking_val = NilObject::NIL, storage_val = NilObject::NIL)
          raise FrozoneException.make(:ArgumentError, "tried to create Fiber object without a block") if block_obj.is_a?(NilObject)
          bo = block_obj.is_a?(ProcObject) ? block_obj.block_object : block_obj
          fiber_klass = klass.is_a?(ClassObject) ? klass : (Core.fiber_class || Core::OBJECT_CLASS)
          blocking = blocking_val.truthy?

          # Process storage: SymbolObject(:__unset__) = inherit, NilObject = empty/lazy, HashObject = explicit
          init_storage = if storage_val.is_a?(SymbolObject) && storage_val.raw == :__unset__
            # Default: inherit parent's storage by copying
            current_storage = ::Fiber[:__frozone_storage__]
            (current_storage && !current_storage.empty?) ? current_storage.dup : nil
          elsif storage_val.is_a?(NilObject)
            # storage: nil means start with empty (lazily initialized on first write)
            nil
          elsif storage_val.is_a?(HashObject)
            raise FrozoneException.make(:FrozenError, "can't modify frozen Hash") if storage_val.frozen_object?
            mri_hash = {}
            storage_val.raw.each do |k, v|
              key_obj = k.is_a?(SymbolObject) ? k : nil
              unless key_obj
                raise FrozoneException.make(:TypeError, "storage key must be a Symbol, not #{k.class_object&.name || 'Object'}")
              end
              mri_hash[key_obj.raw] = v
            end
            mri_hash
          else
            raise FrozoneException.make(:TypeError, "storage must be a Hash")
          end

          fo = FiberObject.new(bo, blocking: blocking, initial_storage: init_storage,
                               frozone_thread_id: CURRENT_FROZONE_THREAD_ID[0])
          fo.instance_variable_set(:@class_object, fiber_klass) if fiber_klass != (Core.fiber_class || Core::OBJECT_CLASS)
          fo
        end

        def fiber_resume(context, fiber_obj, args)
          raise FrozoneException.make(:TypeError, "can't resume a non-Fiber object") unless fiber_obj.is_a?(FiberObject)
          fiber_obj.resume(context, args.raw)
        end

        def fiber_transfer(context, fiber_obj, args)
          raise FrozoneException.make(:TypeError, "can't transfer to a non-Fiber object") unless fiber_obj.is_a?(FiberObject)
          fiber_obj.transfer(context, args.raw)
        end

        def fiber_yield(_, _receiver, args)
          ::Fiber.yield(args.raw.first || NilObject::NIL)
        end

        def fiber_current(_context, _receiver)
          # Return the current Frozone FiberObject if inside one, else the root fiber
          ::Fiber[:frozone_fiber_obj] || (::Fiber[:frozone_root_fiber] ||= FiberObject.root)
        end

        def fiber_alive(_, fiber_obj)
          bool_object_for(fiber_obj.is_a?(FiberObject) && fiber_obj.alive?)
        end

        def fiber_status(_, fiber_obj)
          return NilObject::NIL unless fiber_obj.is_a?(FiberObject)
          SymbolObject.from(fiber_obj.status)
        end

        def fiber_blocking_q(_, fiber_obj)
          return FalseObject::FALSE unless fiber_obj.is_a?(FiberObject)
          bool_object_for(fiber_obj.blocking)
        end

        def fiber_set_blocking(_, fiber_obj, val)
          return NilObject::NIL unless fiber_obj.is_a?(FiberObject)
          fiber_obj.blocking = val.truthy?
          fiber_obj
        end

        # Map internal fiber status to Ruby's inspect status name
        FIBER_STATUS_NAMES = {
          created: "created",
          running: "resumed",
          suspended: "suspended",
          dead: "terminated"
        }.freeze

        def fiber_inspect(_, fiber_obj)
          return StringObject.new("#<Fiber: (root)>") unless fiber_obj.is_a?(FiberObject)
          addr = "0x%016x" % fiber_obj.object_id
          status_name = FIBER_STATUS_NAMES[fiber_obj.status] || fiber_obj.status.to_s
          # Include a source location placeholder to match expected pattern
          source = "(unknown)"
          StringObject.new("#<Fiber:#{addr} #{source} (#{status_name})>")
        end

        def fiber_class_blocking_q(_, _receiver)
          # Returns false for non-blocking mode, or 1 for blocking depth
          current = ::Fiber[:frozone_fiber_obj]
          if current.is_a?(FiberObject) && current.blocking
            IntegerObject.new(1)
          else
            FalseObject::FALSE
          end
        end

        def fiber_raise(context, fiber_obj, msg = NilObject::NIL, message_arg = nil, backtrace_arg = nil, cause_arg = nil)
          raise FrozoneException.make(:FiberError, "cannot raise exception on unborn fiber") if fiber_obj.is_a?(FiberObject) && fiber_obj.status == :created

          # Validate cause: arg in calling context (TypeError/ArgumentError raised here, not in fiber)
          no_cause_sentinel = cause_arg.is_a?(SymbolObject) && cause_arg.raw == :__raise_no_cause__
          no_arg_sentinel = msg.is_a?(SymbolObject) && msg.raw == :__raise_no_arg__
          explicit_cause = !cause_arg.nil? && !no_cause_sentinel

          if no_arg_sentinel && explicit_cause
            raise FrozoneException.make(:ArgumentError, "only cause is given with no arguments")
          end

          if explicit_cause && !cause_arg.is_a?(NilObject)
            raise FrozoneException.make(:TypeError, "exception object expected") unless exception_instance?(cause_arg)
          end

          # If the target fiber is the currently running fiber (or its parent in the resume chain),
          # raise directly rather than scheduling (avoids "double resume" error).
          if fiber_obj.is_a?(FiberObject) && fiber_obj.status == :running
            kernel_raise(context, NilObject::NIL, msg, message_arg, backtrace_arg, cause_arg)
            return NilObject::NIL
          end

          raise FrozoneException.make(:FiberError, "dead fiber called") if !fiber_obj.is_a?(FiberObject) || !fiber_obj.alive?

          exc = begin
            kernel_raise(context, NilObject::NIL, msg, message_arg, backtrace_arg, cause_arg)
            FrozoneException.make(:RuntimeError, "")  # fallback if kernel_raise didn't raise (shouldn't happen)
          rescue FrozoneException => e
            e
          end

          fiber_obj.schedule_raise(exc)
          fiber_obj.resume_for_raise(context)
        end

        def fiber_kill(context, fiber_obj)
          return NilObject::NIL unless fiber_obj.is_a?(FiberObject)
          # Kill unborn fiber: just mark as dead
          if fiber_obj.status == :created
            fiber_obj.kill_unborn!
            return NilObject::NIL
          end
          return NilObject::NIL unless fiber_obj.alive?
          begin
            fiber_obj.schedule_kill
            fiber_obj.resume_for_raise(context)
          rescue FrozoneException
            # fiber terminated
          rescue ::FiberError
            # fiber error during kill
          end
          NilObject::NIL
        end

        def fiber_storage_coerce_key(context, key_obj)
          return key_obj.raw if key_obj.is_a?(SymbolObject)
          if key_obj.is_a?(StringObject)
            return key_obj.raw.to_sym
          end
          # Try to_str for string-like objects
          begin
            str = key_obj.dispatch(context, :to_str, [], {})
            return str.raw.to_sym if str.is_a?(StringObject)
          rescue FrozoneException
            # not string-like, fall through to TypeError
          end
          type_name = key_obj.class_object&.name || "Object"
          raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string")
        end

        def fiber_storage_get(context, _receiver, key_obj)
          sym = fiber_storage_coerce_key(context, key_obj)
          # Use a sub-hash to isolate Frozone-level Fiber storage from MRI-level Fiber storage
          # (outer Frozone vm.rb uses ::Fiber[:file_stack] etc. directly as MRI Arrays)
          val = (::Fiber[:__frozone_storage__] ||= {})[sym]
          val.nil? ? NilObject::NIL : val
        end

        def fiber_storage_set(context, _receiver, key_obj, val)
          sym = fiber_storage_coerce_key(context, key_obj)
          if val.is_a?(NilObject)
            store = ::Fiber[:__frozone_storage__]
            store&.delete(sym)
          else
            (::Fiber[:__frozone_storage__] ||= {})[sym] = val
          end
          val
        end

        # Return the current fiber's storage as a Frozone HashObject (for Fiber#storage)
        def fiber_storage_hash(_context, fiber_obj)
          # Only the owning fiber can access storage
          current = ::Fiber[:frozone_fiber_obj] || (::Fiber[:frozone_root_fiber] ||= FiberObject.root)
          unless fiber_obj.equal?(current)
            raise FrozoneException.make(:ArgumentError, "Fiber storage can only be accessed from the Fiber it belongs to")
          end
          raw = ::Fiber[:__frozone_storage__]
          # Return an empty HashObject if storage is nil or empty (not NilObject)
          ho = HashObject.new
          (raw || {}).each do |sym, val|
            ho[SymbolObject.from(sym)] = val
          end
          ho
        end

        # Set the current fiber's storage from a Frozone value (for Fiber#storage=)
        def fiber_storage_hash_set(_context, fiber_obj, val)
          current = ::Fiber[:frozone_fiber_obj] || (::Fiber[:frozone_root_fiber] ||= FiberObject.root)
          unless fiber_obj.equal?(current)
            raise FrozoneException.make(:ArgumentError, "Fiber storage can only be accessed from the Fiber it belongs to")
          end
          if val.is_a?(NilObject)
            ::Fiber[:__frozone_storage__] = nil
          elsif val.is_a?(HashObject)
            raise FrozoneException.make(:FrozenError, "can't modify frozen Hash") if val.frozen_object?
            mri_hash = {}
            val.raw.each do |k, v|
              unless k.is_a?(SymbolObject)
                type_name = k.is_a?(ObjectObject) ? (k.class_object&.name || "Object") : k.class.name
                raise FrozoneException.make(:TypeError, "storage key must be a Symbol, not #{type_name}")
              end
              mri_hash[k.raw] = v
            end
            ::Fiber[:__frozone_storage__] = mri_hash
          else
            raise FrozoneException.make(:TypeError, "storage must be a Hash")
          end
          val
        end

        def module_ruby2_keywords(context, receiver, names_array)
          names_array.raw.each do |name_obj|
            name = sym_name(name_obj)
            m = receiver.is_a?(ClassObject) ? receiver.lookup_method(name) : receiver.get_method(name)
            if m.nil? || m == ModuleObject::UNDEF_SENTINEL
              raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
            end
            if m.is_a?(Method)
              has_rest = !m.rest_param.nil?
              has_post = m.post_params && !m.post_params.empty?
              has_kw = !m.required_kw_params.empty? || !m.optional_kw_params.empty? || !m.kw_rest_param.nil?
              if has_rest && !has_post && !has_kw
                m.ruby2_keywords = true
              else
                reason = if !has_rest
                  "does not accept splat"
                elsif has_kw
                  "accepts keyword"
                elsif has_post
                  "accepts post-argument"
                end
                src = m.source_location ? " #{m.source_location}" : ""
                msg = StringObject.new("warning: Skipping set of ruby2_keywords flag for #{name}#{src}: #{reason}")
                kernel_warn(context, NilObject::NIL, ArrayObject.new([msg]))
              end
            elsif m.is_a?(DefinedMethod)
              m.ruby2_keywords = true
            end
          end
          NilObject::NIL
        end

        def module_undef_method(_, receiver, name_obj)
          name = sym_name(name_obj)
          # Check if method exists anywhere in hierarchy
          existing = receiver.is_a?(ClassObject) ? receiver.lookup_method(name) : receiver.get_method(name)
          raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'") if existing.nil?
          receiver.undef_method(name)
          receiver
        end

        def module_undef_methods(context, receiver, names_obj)
          names_obj.raw.each { |name_obj| module_undef_method_dispatch(context, receiver, name_obj) }
          receiver
        end

        def module_remove_methods(context, receiver, names_obj)
          names_obj.raw.each { |name_obj| module_remove_method(context, receiver, name_obj) }
          receiver
        end

        def module_undef_method_dispatch(context, receiver, name_obj)
          name = alias_method_coerce_name(context, name_obj)
          if receiver.frozen_object?
            type_name = receiver.is_a?(ClassObject) ? "Class" : "Module"
            raise FrozoneException.make(:FrozenError, "can't modify frozen #{type_name}: #{receiver.inspect_for_frozen}")
          end
          existing = receiver.is_a?(ClassObject) ? receiver.lookup_method(name) : receiver.get_method(name)
          type_word = receiver.is_a?(ClassObject) ? "class" : "module"
          mod_name = module_display_name(context, receiver)
          raise FrozoneException.make(:NameError, "undefined method '#{name}' for #{type_word} '#{mod_name}'") if existing.nil?
          receiver.undef_method(name)
          trigger_method_undefined(context, receiver, name)
          receiver
        end

        def module_remove_method(context, receiver, name_obj)
          name = alias_method_coerce_name(context, name_obj)
          if receiver.frozen_object?
            type_name = receiver.is_a?(ClassObject) ? "Class" : "Module"
            raise FrozoneException.make(:FrozenError, "can't modify frozen #{type_name}: #{receiver.inspect_for_frozen}")
          end
          m = receiver.get_method(name)
          type_word = receiver.is_a?(ClassObject) ? "class" : "module"
          mod_name = receiver.is_a?(ModuleObject) ? receiver.full_name.to_s : receiver.class.name
          raise FrozoneException.make(:NameError, "method '#{name}' not defined in #{mod_name}") if m.nil?
          receiver.remove_method(name)
          trigger_method_removed(context, receiver, name)
          receiver
        end

        ALWAYS_PRIVATE_METHOD_NAMES = %i[initialize initialize_copy initialize_clone initialize_dup respond_to_missing?].freeze

        def sym_name(name_obj)
          return name_obj.raw if name_obj.is_a?(SymbolObject)
          return name_obj.raw.to_sym if name_obj.is_a?(StringObject)
          type_name = name_obj.is_a?(ObjectObject) ? (name_obj.class_object&.name || "Object") : name_obj.class.name
          raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string")
        end

        # Like sym_name but also tries to_str on arbitrary objects (for const_get, module_function, etc.)
        def sym_name_coercing(context, name_obj)
          return name_obj.raw if name_obj.is_a?(SymbolObject)
          return name_obj.raw.to_sym if name_obj.is_a?(StringObject)
          type_name = name_obj.is_a?(ObjectObject) ? (name_obj.class_object&.name || "Object") : name_obj.class.name
          # Try to_str
          has_to_str = begin
            name_obj.dispatch(context, :respond_to?, [SymbolObject.from(:to_str)], {}).truthy?
          rescue FrozoneException
            false
          end
          raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string") unless has_to_str
          result = name_obj.dispatch(context, :to_str, [], {})
          raise FrozoneException.make(:TypeError, "can't convert #{type_name} into String") unless result.is_a?(StringObject)
          result.raw.to_sym
        end

        def alias_method_coerce_name(context, name_obj)
          if name_obj.is_a?(SymbolObject)
            name_obj.raw
          elsif name_obj.is_a?(StringObject)
            name_obj.raw.to_sym
          elsif name_obj.respond_to?(:dispatch)
            # Check respond_to?(:to_str) — if not defined, raise TypeError
            has_to_str = begin
              name_obj.dispatch(context, :respond_to?, [SymbolObject.from(:to_str)], {}).truthy?
            rescue FrozoneException
              false
            end
            raise FrozoneException.make(:TypeError, "#{name_obj.class_object&.name} is not a symbol nor a string") unless has_to_str
            # Call to_str; if it raises, propagate the exception as-is
            result = name_obj.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "can't convert #{name_obj.class_object&.name} into String") unless result.is_a?(StringObject)
            result.raw.to_sym
          else
            raise FrozoneException.make(:TypeError, "#{name_obj.class} is not a symbol nor a string")
          end
        end

        def module_alias_method(context, receiver, new_name_obj, old_name_obj)
          new_name = alias_method_coerce_name(context, new_name_obj)
          old_name = alias_method_coerce_name(context, old_name_obj)
          method = receiver.lookup_method(old_name)
          # Modules may alias methods defined on Object (e.g. Kernel aliasing Object methods)
          method ||= Core::OBJECT_CLASS.lookup_method(old_name) unless receiver.is_a?(ClassObject)
          # Inside a refine block, receiver is the refinement module. If not found there,
          # look in the refined class (e.g. alias_method :x, :count should find Array#count
          # when inside `refine Array do ... end`).
          if method.nil?
            refined_class_obj = receiver.get_ivar(:@__refined_class__)
            if refined_class_obj && !refined_class_obj.is_a?(NilObject)
              method = refined_class_obj.lookup_method(old_name)
            end
          end
          raise FrozoneException.make(:NameError, "undefined method '#{old_name}'") if method.nil?
          aliased = method.alias_as(new_name)
          aliased.visibility = :private if ALWAYS_PRIVATE_METHOD_NAMES.include?(new_name)
          receiver.set_method(new_name, aliased)
          trigger_method_added(context, receiver, new_name)
          SymbolObject.from(new_name)
        end

        def module_define_method(context, receiver, name_obj, block)
          name = alias_method_coerce_name(context, name_obj)
          method = if block.is_a?(UnboundMethodObject)
                     raw = block.raw_method
                     # Validate that the UnboundMethod can be bound to receiver
                     owner = block.unbound_owner
                     if owner && receiver.is_a?(ModuleObject) && !(receiver.is_a?(ClassObject) && receiver.is_singleton_class)
                       # Module owners: any class can define the method (modules are mixin-able to anything)
                       # Class/singleton class owners: receiver must be a subclass/ancestor
                       if owner.is_a?(ClassObject) && owner.is_singleton_class
                         # singleton class owner: can't bind to another class
                         type_name = owner.full_name.to_s
                         raise FrozoneException.make(:TypeError, "can't bind singleton method to a different class")
                       elsif owner.is_a?(ClassObject)
                         # receiver must be owner or a subclass of owner
                         unless receiver.equal?(owner) || receiver.ancestors_include?(owner)
                           type_name = owner.full_name.to_s
                           raise FrozoneException.make(:TypeError, "bind argument must be a subclass of #{type_name}")
                         end
                       end
                       # Pure module owner: no constraint
                     end
                     raw.is_a?(Method) ? raw.bound_copy(name, receiver) : DefinedMethod.new(name, raw.block_obj, receiver)
                   elsif block.is_a?(BoundMethodObject)
                     raw = block.raw_method
                     # Validate: bound method from a singleton class can't be defined on another class
                     bound_owner = block.bound_owner
                     if bound_owner.is_a?(ClassObject) && bound_owner.is_singleton_class
                       raise FrozoneException.make(:TypeError, "can't bind singleton method to a different class")
                     elsif bound_owner.is_a?(ClassObject) && receiver.is_a?(ClassObject)
                       # Check receiver is subclass of the method's defining class
                       unless receiver.ancestors_include?(bound_owner) || bound_owner.ancestors_include?(receiver)
                         raise FrozoneException.make(:TypeError, "bind argument must be a subclass of #{bound_owner.full_name}")
                       end
                     end
                     raw.is_a?(Method) ? raw.bound_copy(name, receiver) : DefinedMethod.new(name, raw.block_obj, receiver)
                   elsif block.is_a?(ProcObject)
                     DefinedMethod.new(name, block.block_object, receiver)
                   elsif block.respond_to?(:invoke)
                     DefinedMethod.new(name, block, receiver)
                   else
                     type_name = block.is_a?(ObjectObject) ? (block.class_object&.name || "Object") : block.class.name
                     raise FrozoneException.make(:TypeError, "wrong argument type #{type_name} (expected Proc/Method/UnboundMethod)")
                   end
          vis = ALWAYS_PRIVATE_METHOD_NAMES.include?(name) ? :private : receiver.current_visibility
          if vis == :module_function
            method.visibility = :private
            receiver.set_method(name, method)
            trigger_method_added(context, receiver, name)
            sm = method.respond_to?(:bound_copy) ? method.bound_copy(name, receiver.singleton_class) : method.dup
            sm.visibility = :public
            receiver.singleton_class.set_method(name, sm)
            trigger_method_added(context, receiver.singleton_class, name)
          else
            method.visibility = vis
            receiver.set_method(name, method)
            trigger_method_added(context, receiver, name)
          end
          SymbolObject.from(name)
        end

        def module_constants(_, receiver, inherit_obj = TrueObject::TRUE)
          inherit = inherit_obj.truthy?
          seen = {}
          result = []
          if inherit
            # Include own constants + prepended/included module constants + superclass constants.
            # Stops before Object/BasicObject (MRI behaviour: ambient top-level constants are
            # not included in a specific class's constants, but Object.constants returns them all
            # because they live in Object's own constants_table).
            collect_consts = lambda do |mod|
              next unless mod.is_a?(ModuleObject)
              mod.prepends.each { |m| collect_consts.call(m) }
              keys = mod.constants_table.keys | mod.instance_variable_get(:@autoloads).keys
              keys.each do |k|
                next if seen[k]
                next if mod.constant_private?(k)
                seen[k] = true
                result << SymbolObject.from(k)
              end
              mod.modules.each { |m| collect_consts.call(m) }
              sup = mod.is_a?(ClassObject) ? mod.superclass : nil
              # Don't recurse into Object or BasicObject — their constants are ambient/top-level
              if sup && !sup.equal?(Core::OBJECT_CLASS) && !sup.equal?(Core::BASIC_OBJECT_CLASS)
                collect_consts.call(sup)
              end
            end
            collect_consts.call(receiver)
          else
            keys = receiver.constants_table.keys | receiver.instance_variable_get(:@autoloads).keys
            keys.each do |k|
              next if receiver.constant_private?(k)
              result << SymbolObject.from(k)
            end
          end
          ArrayObject.new(result)
        end

        CVAR_NAME_RE = /\A@@[^@!? ][^!? ]*\z/.freeze

        def validate_cvar_name!(name_str, name_obj, receiver: nil)
          unless name_str.start_with?('@@') && name_str.length > 2 && name_str[2] != '@'
            exc = FrozoneException.make(:NameError, "`#{name_str}' is not allowed as a class variable name")
            exc.vm_object.set_ivar(:@name, name_obj)
            exc.vm_object.set_ivar(:@receiver, receiver) if receiver
            raise exc
          end
        end

        def coerce_cvar_name(context, name_obj)
          if name_obj.is_a?(SymbolObject)
            name_obj.raw.to_s
          elsif name_obj.is_a?(StringObject)
            name_obj.raw
          else
            # Try to_str
            has_to_str = begin
              name_obj.dispatch(context, :respond_to?, [SymbolObject.from(:to_str)], {}).truthy?
            rescue FrozoneException
              false
            end
            unless has_to_str
              type_name = name_obj.is_a?(ObjectObject) ? (name_obj.class_object&.name || "Object") : name_obj.class.name
              raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string")
            end
            result = name_obj.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "to_str must return String") unless result.is_a?(StringObject)
            result.raw
          end
        end

        def class_var_defined_in_ancestors?(receiver, name)
          # Also check the eigenclass (singleton class) for class variables set inside `class << self`
          return true if receiver.eigenclass&.class_variables&.key?(name)
          ancestors = receiver.respond_to?(:ancestors_list) ? receiver.ancestors_list : [receiver]
          ancestors.any? { |a| a.class_variables.key?(name) }
        end

        def get_class_var_from_ancestors(receiver, name)
          return receiver.eigenclass.class_variables[name] if receiver.eigenclass&.class_variables&.key?(name)
          ancestors = receiver.respond_to?(:ancestors_list) ? receiver.ancestors_list : [receiver]
          ancestors.each do |a|
            return a.class_variables[name] if a.class_variables.key?(name)
          end
          nil
        end

        def module_class_variable_defined(context, receiver, name_obj)
          name_str = coerce_cvar_name(context, name_obj)
          validate_cvar_name!(name_str, name_obj)
          name = name_str.to_sym
          class_var_defined_in_ancestors?(receiver, name) ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_class_variables(_, receiver, inherit_obj = TrueObject::TRUE)
          inherit = inherit_obj.truthy?
          seen = {}
          if inherit
            # Collect from eigenclass, this class, and superclass chain
            receiver.eigenclass&.class_variables&.each_key { |k| seen[k] = true }
            c = receiver
            while c
              c.class_variables.each_key { |k| seen[k] = true }
              c = c.is_a?(ClassObject) ? c.superclass : nil
            end
          else
            # Only this class's own class variables (+ eigenclass for singleton objects)
            receiver.eigenclass&.class_variables&.each_key { |k| seen[k] = true }
            receiver.class_variables.each_key { |k| seen[k] = true }
          end
          ArrayObject.new(seen.keys.map { |k| SymbolObject.from(k) })
        end

        def module_class_variable_get(context, receiver, name_obj)
          name_str = coerce_cvar_name(context, name_obj)
          validate_cvar_name!(name_str, name_obj, receiver: receiver)
          name = name_str.to_sym
          val = get_class_var_from_ancestors(receiver, name)
          if val.nil?
            exc = FrozoneException.make(:NameError, "uninitialized class variable #{name} in #{receiver.name || '#<Module>'}")
            exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
            exc.vm_object.set_ivar(:@receiver, receiver)
            raise exc
          end
          val
        end

        def module_class_variable_set(context, receiver, name_obj, value)
          name_str = coerce_cvar_name(context, name_obj)
          validate_cvar_name!(name_str, name_obj)
          name = name_str.to_sym
          if receiver.is_a?(ObjectObject) && receiver.frozen_object?
            raise FrozoneException.make(:FrozenError, "can't modify frozen #{receiver.class_object&.name || 'Object'}: #{receiver.inspect rescue '?'}")
          end
          receiver.set_class_var(name, value)
          value
        end

        def module_private_constant(context, receiver, *name_objs)
          name_objs.each do |name_obj|
            name = sym_name_coercing(context, name_obj)
            raise FrozoneException.make(:NameError, "constant #{receiver.full_name}::#{name} not defined") if receiver.get_constant(name).nil? && receiver.get_autoload(name).nil?
            receiver.mark_constant_private(name)
          end
          receiver
        end

        def module_public_constant(context, receiver, *name_objs)
          name_objs.each do |name_obj|
            name = sym_name_coercing(context, name_obj)
            raise FrozoneException.make(:NameError, "constant #{receiver.full_name}::#{name} not defined") if receiver.get_constant(name).nil? && receiver.get_autoload(name).nil?
            receiver.private_constants_table&.delete(name)
          end
          receiver
        end

        def module_remove_const(context, receiver, name_obj)
          name = sym_name_coercing(context, name_obj)
          val = receiver.get_constant(name)
          if val.nil?
            # Check if it's an autoload registration
            if receiver.get_autoload(name)
              receiver.remove_autoload(name)
              return NilObject::NIL
            end
            raise FrozoneException.make(:NameError, "constant #{name} not defined")
          end
          maybe_warn_deprecated_constant(context, receiver, name)
          receiver.constants_table.delete(name)
          val
        end

        def module_remove_class_variable(_, receiver, name_obj)
          name = sym_name(name_obj)
          raise FrozoneException.make(:NameError, "class variable #{name} not defined for #{receiver.name}") unless receiver.class_variables.key?(name)
          receiver.class_variables.delete(name) || NilObject::NIL
        end

        def module_name(_, receiver)
          if receiver.instance_variable_defined?(:@temporary_name)
            temp = receiver.instance_variable_get(:@temporary_name)
            if temp
              # Cached temp name string — keyed by temp string value
              cached = receiver.instance_variable_get(:@cached_name_str)
              return cached if cached&.raw == temp
              s = StringObject.new(temp)
              receiver.instance_variable_set(:@cached_name_str, s)
              return s
            end
          end
          return NilObject::NIL unless receiver.name
          # Cache the name string for identity stability
          full = receiver.full_name.to_s
          cached = receiver.instance_variable_get(:@cached_name_str)
          return cached if cached&.raw == full
          s = StringObject.new(full)
          receiver.instance_variable_set(:@cached_name_str, s)
          s
        end

        def module_singleton_class_q(_, receiver)
          receiver.is_a?(ClassObject) && receiver.is_singleton_class ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_in_method_scope_q(context, _receiver)
          # Check the CALLER's frame (parent of using's own method frame).
          # `using` itself has current_method set; we want to know if its caller does.
          caller_frame = context.frame.parent_frame
          caller_frame&.method_frame&.current_method ? TrueObject::TRUE : FalseObject::FALSE
        end

        # Collect all refinements from mod and its ancestors (depth-first, included modules).
        # Returns a hash mapping klass.object_id => refinement_module.
        def collect_refinements_from_module(mod)
          refinements = {}
          mod.ancestors_list.reverse_each do |ancestor|
            next if ancestor.equal?(mod)
            if ancestor.is_a?(ModuleObject) && !ancestor.is_a?(ClassObject)
              anc_refs_obj = ancestor.get_ivar(:@__refinements__)
              next if anc_refs_obj.is_a?(NilObject) || !anc_refs_obj.is_a?(HashObject)
              # @__refinements__ is a Frozone HashObject with Integer keys (object_id) => ModuleObject values
              anc_refs_obj.raw.each do |k, v|
                key = k.is_a?(IntegerObject) ? k.raw : k
                refinements[key] = v if v.is_a?(ModuleObject)
              end
            end
          end
          own_refs_obj = mod.get_ivar(:@__refinements__)
          unless own_refs_obj.is_a?(NilObject) || !own_refs_obj.is_a?(HashObject)
              own_refs_obj.raw.each do |k, v|
              key = k.is_a?(IntegerObject) ? k.raw : k
              refinements[key] = v if v.is_a?(ModuleObject)
            end
          end
          refinements
        end

        def module_using(context, _receiver, mod)
          raise FrozoneException.make(:TypeError, "wrong argument type #{frozone_class_name(mod)} (expected Module)") unless mod.is_a?(ModuleObject)
          raise FrozoneException.make(:TypeError, "wrong argument type Class (expected Module)") if mod.is_a?(ClassObject)
          caller_frame = context.frame.parent_frame
          raise FrozoneException.make(:RuntimeError, "Module#using is not permitted in methods") if caller_frame&.method_frame&.current_method
          new_refs = collect_refinements_from_module(mod)
          unless new_refs.empty?
            target_frame = caller_frame
            target_frame.active_refinements ||= {}
            target_frame.active_refinements.merge!(new_refs)
          end
          NilObject::NIL
        end

        def module_used_refinements(context, _klass)
          # used_refinements returns refinements active in the CALLING scope.
          # When called as an intrinsic, context.frame is the module body frame itself.
          # When called via a method wrapper, context.frame is the method frame and
          # context.frame.parent_frame is the module body frame.
          # Check both: current frame and its parent.
          frame = context.frame
          refs = frame&.active_refinements
          if (refs.nil? || refs.empty?) && frame
            refs = frame.parent_frame&.active_refinements
          end
          return ArrayObject.new([]) unless refs && !refs.empty?
          ArrayObject.new(refs.values)
        end

        # Evaluate a refine block with all the refining module's own refinements active.
        # This enables cross-refinement calls inside the refine block.
        def module_refine_eval(context, refining_mod, refinement_mod, block)
          # Collect the refining module's own refinements (NOT ancestors), using Frozone's get_ivar
          own_refs_obj = refining_mod.get_ivar(:@__refinements__)
          own_refs = {}
          unless own_refs_obj.is_a?(NilObject) || !own_refs_obj.is_a?(HashObject)
            own_refs_obj.raw.each do |k, v|
              key = k.is_a?(IntegerObject) ? k.raw : k
              own_refs[key] = v if v.is_a?(ModuleObject)
            end
          end
          # Also include the refinement_mod itself (for the class being refined)
          refined_class_obj = refinement_mod.get_ivar(:@__refined_class__)
          refined_class = refined_class_obj.is_a?(NilObject) ? nil : refined_class_obj
          all_refs = own_refs.dup
          all_refs[refined_class.object_id] = refinement_mod if refined_class

          block_obj = block.is_a?(BlockObject) ? block : (block.is_a?(ProcObject) ? block.block_object : block)
          unless block_obj.is_a?(BlockObject)
            module_eval(context, refinement_mod, block)
            return NilObject::NIL
          end

          # Temporarily install refinements and refining_module on the block's enclosing frame.
          # BlockObject#invoke creates a new_frame inheriting active_refinements and
          # current_refining_module from enclosing_frame, so setting them here makes them
          # visible inside the refine block body (for cross-refinement and method.refining_module).
          enc_frame = block_obj.enclosing_frame
          prev_enc_refs = enc_frame.active_refinements
          prev_enc_refining_mod = enc_frame.current_refining_module
          enc_frame.active_refinements = if all_refs.empty?
            prev_enc_refs
          elsif prev_enc_refs
            prev_enc_refs.merge(all_refs)
          else
            all_refs
          end
          enc_frame.current_refining_module = refining_mod
          begin
            module_eval(context, refinement_mod, block)
          ensure
            enc_frame.active_refinements = prev_enc_refs
            enc_frame.current_refining_module = prev_enc_refining_mod
          end
          NilObject::NIL
        end

        def module_set_temporary_name(_, receiver, name_obj)
          # Compute at runtime whether this module has a permanent name
          is_permanent = if receiver.name
            c = receiver
            all_named = true
            while c && !c.equal?(Core::OBJECT_CLASS)
              unless c.name
                all_named = false
                break
              end
              c = c.namespace
            end
            all_named
          else
            false
          end
          if name_obj.is_a?(NilObject)
            raise FrozoneException.make(:RuntimeError, "can't change permanent name") if is_permanent
            receiver.instance_variable_set(:@temporary_name, nil)
            receiver.clear_name! unless is_permanent
            return receiver
          end
          raise FrozoneException.make(:TypeError, "#{frozone_class_name(name_obj)} is not a String") unless name_obj.is_a?(StringObject)
          name_s = name_obj.raw
          raise FrozoneException.make(:ArgumentError, "empty class/module name") if name_s.empty?
          # Reject valid constant paths: all :: components are valid constant names
          if name_s.start_with?("::")
            raise FrozoneException.make(:ArgumentError, "the temporary name must not be a constant path to avoid confusion")
          end
          parts = name_s.split("::", -1)
          if parts.all? { |p| p =~ /\A[A-Z][a-zA-Z0-9_]*\z/ }
            raise FrozoneException.make(:ArgumentError, "the temporary name must not be a constant path to avoid confusion")
          end
          raise FrozoneException.make(:RuntimeError, "can't change permanent name") if is_permanent
          receiver.instance_variable_set(:@temporary_name, name_s)
          receiver.instance_variable_set(:@cached_name_str, nil)
          receiver
        end

        CONST_NAME_RE = /\A[A-Z\p{Lu}][\p{L}\p{N}_]*\z/u.freeze

        def validate_const_name!(name_s, orig_name_obj)
          orig_s = orig_name_obj.is_a?(SymbolObject) ? orig_name_obj.raw.to_s : (orig_name_obj.is_a?(StringObject) ? orig_name_obj.raw : name_s)
          # Encode to UTF-8 for Unicode regex matching (handles EUC-JP etc.)
          check_s = name_s.encoding == Encoding::UTF_8 ? name_s : name_s.encode("UTF-8", invalid: :replace, undef: :replace)
          raise FrozoneException.make(:NameError, "wrong constant name #{orig_s}") unless check_s =~ CONST_NAME_RE
        end

        def resolve_const_path(context, name_obj, receiver, inherit)
          is_symbol = name_obj.is_a?(SymbolObject)
          name_str = if is_symbol
            name_obj.raw.to_s
          elsif name_obj.is_a?(StringObject)
            name_obj.raw
          else
            r = sym_name_coercing(context, name_obj)
            r.to_s
          end
          # Symbols must be simple constant names — no :: allowed
          if is_symbol && (name_str.include?("::") || name_str.empty?)
            raise FrozoneException.make(:NameError, "wrong constant name #{name_str.inspect}")
          end
          # Handle :: prefix (absolute path) — only valid for Strings
          start = receiver
          remaining = name_str
          if remaining.start_with?("::")
            start = Core::OBJECT_CLASS
            remaining = remaining[2..]
          end
          # Split on ::
          parts = remaining.split("::", -1)
          # '::' alone (or leading :: with empty remainder) should raise NameError
          if parts.empty? || parts.any?(&:empty?)
            orig_s = name_obj.is_a?(SymbolObject) ? name_obj.raw.to_s : (name_obj.is_a?(StringObject) ? name_obj.raw : remaining)
            raise FrozoneException.make(:NameError, "wrong constant name #{orig_s}")
          end
          [start, parts]
        end

        def module_const_defined(context, receiver, name_obj, inherit = TrueObject::TRUE)
          inherit_b = inherit.is_a?(FalseObject) || inherit.equal?(NilObject::NIL) ? false : true
          start, parts = resolve_const_path(context, name_obj, receiver, inherit_b)
          parts.each_with_index do |part, i|
            validate_const_name!(part, name_obj)
            sym = part.to_sym
            last = (i == parts.size - 1)
            if last
              c = if inherit_b
                val, = start.lookup_constant_with_owner(sym)
                # Fall through to Object only if receiver inherits from Object
                # (BasicObject subclasses should NOT see Object constants)
                object_visible = !start.equal?(Core::OBJECT_CLASS) &&
                  (!start.is_a?(ClassObject) || start.ancestors_list.any? { |a| a.equal?(Core::OBJECT_CLASS) })
                val || (object_visible && Core::OBJECT_CLASS.lookup_constant(sym)) ||
                  start.lookup_autoload(sym, inherit: true)
              else
                start.get_constant(sym) || start.get_autoload(sym)
              end
              # An autoload path that is already in $LOADED_FEATURES is not considered defined
              if c.is_a?(::String)
                resolved = resolve_load_path(c)
                c = nil if resolved && GLOBALS[:"$LOADED_FEATURES"].raw.any? { |s| s.raw == resolved }
              end
              return !c.nil? && c != false ? TrueObject::TRUE : FalseObject::FALSE
            else
              # For non-last parts: inherit=false means only search own constants
              val = if inherit_b
                v, = start.lookup_constant_with_owner(sym)
                v
              else
                start.get_constant(sym)
              end
              return FalseObject::FALSE if val.nil?
              return FalseObject::FALSE unless val.is_a?(ModuleObject)
              start = val
            end
          end
          FalseObject::FALSE
        end

        def module_const_get(context, receiver, name_obj, inherit = TrueObject::TRUE)
          inherit_b = inherit.is_a?(FalseObject) || inherit.equal?(NilObject::NIL) ? false : true
          start, parts = resolve_const_path(context, name_obj, receiver, inherit_b)
          orig_name_obj = name_obj
          scoped = parts.size > 1  # multi-component path like A::B
          parts.each_with_index do |part, i|
            validate_const_name!(part, orig_name_obj)
            sym = part.to_sym
            last = (i == parts.size - 1)
            if last
              c = if !inherit_b
                # inherit=false: only own constants
                start.get_constant(sym)
              elsif !scoped
                # Simple lookup: walk own + included modules, then also search Object for toplevel constants
                start.lookup_constant(sym) ||
                  (!start.equal?(Core::OBJECT_CLASS) && Core::OBJECT_CLASS.lookup_constant(sym))
              else
                # Scoped path (A::B): only search start's hierarchy, NOT Object
                start.lookup_constant(sym)
              end
              if !c || c.equal?(false)
                # Check for autoload before const_missing
                autoload_path = start.lookup_autoload(sym, inherit: inherit_b)
                autoload_path ||= (!inherit_b ? nil : (!start.equal?(Core::OBJECT_CLASS) && Core::OBJECT_CLASS.lookup_autoload(sym, inherit: true)))
                if autoload_path
                  begin
                    kernel_require(context, nil, StringObject.new(autoload_path))
                  rescue FrozoneException, StandardError
                    # If require fails, fall through to const_missing
                  end
                  c = if !inherit_b
                    start.get_constant(sym)
                  elsif !scoped
                    start.lookup_constant(sym) || (!start.equal?(Core::OBJECT_CLASS) && Core::OBJECT_CLASS.lookup_constant(sym))
                  else
                    start.lookup_constant(sym)
                  end
                end
                return start.dispatch(context, :const_missing, [SymbolObject.from(sym)], {}, nil, private_ok: true) if !c || c.equal?(false)
              end
              _, owner = start.lookup_constant_with_owner(sym)
              maybe_warn_deprecated_constant(context, owner, sym)
              return c
            else
              c = start.lookup_constant(sym)
              # For non-last parts of a scoped name, also fall back to Object (top-level constants)
              c ||= Core::OBJECT_CLASS.lookup_constant(sym) unless start.equal?(Core::OBJECT_CLASS)
              if c.nil?
                # Check autoload for intermediate path components
                autoload_path = start.lookup_autoload(sym, inherit: true)
                autoload_path ||= Core::OBJECT_CLASS.lookup_autoload(sym, inherit: true) unless start.equal?(Core::OBJECT_CLASS)
                if autoload_path
                  begin
                    kernel_require(context, nil, StringObject.new(autoload_path))
                    c = start.lookup_constant(sym)
                    c ||= Core::OBJECT_CLASS.lookup_constant(sym) unless start.equal?(Core::OBJECT_CLASS)
                  rescue FrozoneException, StandardError
                    # fall through to const_missing
                  end
                end
                return start.dispatch(context, :const_missing, [SymbolObject.from(sym)], {}) if c.nil?
              end
              raise FrozoneException.make(:TypeError, "#{part} is not a module") unless c.is_a?(ModuleObject)
              start = c
            end
          end
          NilObject::NIL
        end

        def module_const_source_location(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          inherit_b = inherit_obj.truthy?
          start, parts = resolve_const_path(context, name_obj, receiver, inherit_b)
          scoped = parts.size > 1

          # Walk all non-last parts
          parts[0..-2].each do |part|
            validate_const_name!(part, name_obj)
            sym = part.to_sym
            c = start.lookup_constant(sym)
            c ||= Core::OBJECT_CLASS.lookup_constant(sym) unless start.equal?(Core::OBJECT_CLASS)
            return NilObject::NIL unless c.is_a?(ModuleObject)
            start = c
          end

          last_part = parts.last
          validate_const_name!(last_part, name_obj)
          name = last_part.to_sym

          # Build search chain
          search_chain = if inherit_b && !scoped
            result = []
            seen = {}
            walk = lambda do |mod|
              next unless mod.is_a?(ModuleObject)
              next if seen[mod.object_id]
              seen[mod.object_id] = true
              mod.prepends.each { |m| walk.call(m) }
              result << mod
              mod.modules.each { |m| walk.call(m) }
              sup = mod.is_a?(ClassObject) ? mod.superclass : nil
              walk.call(sup) if sup
            end
            walk.call(start)
            walk.call(Core::OBJECT_CLASS) unless seen[Core::OBJECT_CLASS.object_id]
            result
          else
            [start]
          end

          search_chain.each do |mod|
            # Check autoload first (constant not yet loaded)
            if mod.get_autoload(name)
              loc = mod.get_autoload_location(name)
              if loc
                return ArrayObject.new([StringObject.new(loc[0]), IntegerObject.new(loc[1])])
              else
                return ArrayObject.new([])
              end
            end
            next unless mod.constants_table.key?(name)
            loc = mod.get_constant_location(name)
            if loc
              return ArrayObject.new([StringObject.new(loc[0]), IntegerObject.new(loc[1])])
            else
              return ArrayObject.new([])
            end
          end
          NilObject::NIL
        end

        def module_autoload(context, receiver, name_obj, path_obj)
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{frozone_class_name(receiver)}: #{receiver.full_name}") if receiver.frozen_object?
          name = sym_name(name_obj)
          path = if path_obj.is_a?(StringObject)
            path_obj.raw
          else
            to_path_result = begin
              r = path_obj.dispatch(context, :to_path, [], {})
              r.is_a?(StringObject) ? r.raw : nil
            rescue FrozoneException
              nil
            end
            if to_path_result
              to_path_result
            else
              begin
                r2 = path_obj.dispatch(context, :to_str, [], {})
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{frozone_class_name(path_obj)} into String") unless r2.is_a?(StringObject)
                r2.raw
              rescue FrozoneException => e
                raise if e.frozone_class_name == :TypeError
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{frozone_class_name(path_obj)} into String")
              end
            end
          end
          raise FrozoneException.make(:ArgumentError, "empty file name") if path.empty?
          unless name.to_s =~ /\A[A-Z][a-zA-Z0-9_]*\z/
            raise FrozoneException.make(:NameError, "wrong constant name #{name}")
          end
          src_loc = context.call_site ? context.call_site.split(':').then { |parts| parts.length >= 2 ? [parts[0..-2].join(':'), parts[-1].to_i] : nil } : nil
          receiver.set_autoload(name, path, source_location: src_loc)
          Frozone::Vm.trigger_const_added(context, receiver, name)
          NilObject::NIL
        end

        def module_autoload_q(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name(name_obj)
          inherit = inherit_obj.truthy?
          path = receiver.lookup_autoload(name, inherit: inherit)
          return NilObject::NIL unless path
          # Return nil if file is already in $LOADED_FEATURES (treated as already loaded)
          loaded = GLOBALS[:"$LOADED_FEATURES"]
          resolved = resolve_load_path(path)
          return NilObject::NIL if resolved && loaded.raw.any? { |s| s.raw == resolved }
          StringObject.new(path)
        end

        def module_const_set(context, receiver, name_obj, value)
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{frozone_class_name(receiver)}: #{receiver.full_name}") if receiver.frozen_object?
          # Try to_str coercion for non-Symbol/String name
          name_obj = if name_obj.is_a?(SymbolObject) || name_obj.is_a?(StringObject)
            name_obj
          else
            coerced = begin
              name_obj.dispatch(context, :to_str, [], {})
            rescue FrozoneException
              raise FrozoneException.make(:TypeError, "#{frozone_class_name(name_obj)} is not a symbol nor a string")
            end
            raise FrozoneException.make(:TypeError, "can't convert #{frozone_class_name(name_obj)} into String (to_str gives #{frozone_class_name(coerced)})") unless coerced.is_a?(StringObject)
            coerced
          end
          name = sym_name(name_obj)
          name_s = name.to_s
          check_s = name_s.encoding == Encoding::UTF_8 ? name_s : name_s.encode("UTF-8", invalid: :replace, undef: :replace)
          raise FrozoneException.make(:NameError, "wrong constant name #{name_s}") unless check_s =~ CONST_NAME_RE
          emit_vm_warning(context, "already initialized constant #{receiver.name}::#{name}") if receiver.get_constant(name)
          # Use call_site as source location for dynamically set constants
          src_loc = context.call_site ? context.call_site.split(':').then { |parts| parts.length >= 2 ? [parts[0..-2].join(':'), parts[-1].to_i] : nil } : nil
          receiver.set_constant(name, value, source_location: src_loc)
          # Auto-name anonymous classes/modules (same as constant_write.rb)
          if value.is_a?(ModuleObject) && (value.name.nil? || !value.name_permanent)
            container_permanent = receiver.equal?(Core::OBJECT_CLASS) || receiver.name_permanent
            if value.name.nil? || container_permanent
              value.set_name(name)
              value.namespace = receiver.equal?(Core::OBJECT_CLASS) ? nil : receiver
              value.instance_variable_set(:@temporary_name, nil) if value.instance_variable_defined?(:@temporary_name)
              value.mark_name_permanent! if container_permanent
            end
          end
          Frozone::Vm.trigger_const_added(context, receiver, name)
          value
        end

        def module_eval(context, receiver, block)
          return NilObject::NIL if block.nil? || block.is_a?(NilObject)
          prev_vis = receiver.is_a?(ModuleObject) ? receiver.current_visibility : nil
          receiver.current_visibility = :public if prev_vis
          context.scopes << receiver
          begin
            block.invoke(context, [receiver], receiver: receiver, def_scope: receiver)
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
            block.invoke(context, args, receiver: receiver, def_scope: receiver)
          ensure
            context.scopes.pop
            receiver.current_visibility = prev_vis if prev_vis
          end
        end

        def module_eval_string(context, receiver, code_obj, file_obj = NilObject::NIL, line_obj = NilObject::NIL)
          code = code_obj.is_a?(StringObject) ? code_obj.raw : code_obj.to_s
          file = file_obj.is_a?(StringObject) ? file_obj.raw : nil
          line = line_obj.is_a?(IntegerObject) ? line_obj.raw : nil
          # Build caller location string if no file given
          file ||= (context.call_site ? "(eval at #{context.call_site})" : "(eval)")
          line ||= 1
          parser = Parser.new(code, filepath: file, line: line)
          ast = parser.ast
          # Evaluate in a frame where self = receiver (the module/class)
          # Reset current_visibility to :public for the eval context (like class body)
          prev_vis = receiver.is_a?(ModuleObject) ? receiver.current_visibility : nil
          receiver.current_visibility = :public if prev_vis
          # Build scope chain from receiver's namespace nesting (innermost last),
          # so constant lookup sees the receiver's enclosing namespaces.
          eval_scopes = [Core::OBJECT_CLASS]
          if receiver.is_a?(ModuleObject)
            chain = []
            ns = receiver
            while ns.is_a?(ModuleObject) && !ns.equal?(Core::OBJECT_CLASS)
              chain.unshift(ns)
              ns = ns.namespace
            end
            chain.each { |m| eval_scopes << m unless eval_scopes.include?(m) }
          end
          new_frame = Frame.new(receiver, parser.top_level_locals, eval_scopes)
          # Inherit active refinements from the calling frame (lexical scope for eval)
          new_frame.active_refinements = context.frame.active_refinements if context.frame&.active_refinements
          context.push_frame(new_frame)
          context.scopes << receiver
          begin
            ast.evaluate(context)
          ensure
            context.pop_frame
            context.scopes.pop
            receiver.current_visibility = prev_vis if prev_vis
          end
        end

        def module_nesting(context, _receiver)
          # Return the lexical nesting: use the calling frame's scopes (method definition site),
          # falling back to context.scopes for top-level calls.
          # For method frames (def self.foo style), singleton classes are appended at the end
          # for super lookup but are NOT part of the lexical nesting — filter them out.
          # For class body frames (class << self), singleton classes ARE part of the nesting.
          frame = context.frames.length >= 2 ? context.frames[-2] : context.frame
          scopes = frame.scopes
          if frame.method_frame.equal?(frame)
            # Method invocation frame: filter out singleton classes (added for super, not nesting)
            scopes = scopes.reject { |s| s.is_a?(ClassObject) && s.is_singleton_class }
          end
          lex = (!scopes.empty? && scopes[0].equal?(Core::OBJECT_CLASS)) ? scopes[1..] : scopes
          ArrayObject.new(lex.reverse)
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

        def module_instance_methods(_, receiver, include_super_obj = TrueObject::TRUE, vis_filter = nil)
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          collect = lambda do |mod|
            mod.methods_table.each do |name, m|
              next if seen[name]
              seen[name] = true
              next if m == ModuleObject::UNDEF_SENTINEL
              next if vis_filter && m.visibility != vis_filter
              result << SymbolObject.from(name) if m.visibility == :public || m.visibility == :protected
            end
          end
          walk = lambda do |mod|
            mod.prepends.each { |m| walk.call(m) }
            collect.call(mod)
            mod.modules.each { |m| walk.call(m) }
            walk.call(mod.superclass) if mod.is_a?(ClassObject) && mod.superclass
          end
          if include_super
            walk.call(receiver)
          else
            collect.call(receiver)
          end
          # For refinement modules: include the refined class's instance methods.
          # MRI's Refinement#instance_methods returns methods including those of the refined module.
          refined_class_obj = receiver.get_ivar(:@__refined_class__)
          if refined_class_obj && !refined_class_obj.is_a?(NilObject)
            walk.call(refined_class_obj)
          end
          ArrayObject.new(result)
        end

        def module_public_only_instance_methods(ctx, receiver, include_super_obj = TrueObject::TRUE)
          module_instance_methods(ctx, receiver, include_super_obj, :public)
        end

        def module_undefined_instance_methods(_, receiver)
          result = []
          receiver.methods_table.each do |name, m|
            result << SymbolObject.from(name) if m == ModuleObject::UNDEF_SENTINEL
          end
          ArrayObject.new(result)
        end

        def module_method_defined(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name_coercing(context, name_obj)
          inherit = inherit_obj.truthy?
          m = inherit ? receiver.lookup_method(name) : receiver.get_method(name)
          m && m != ModuleObject::UNDEF_SENTINEL && (m.visibility == :public || m.visibility == :protected) ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_private_instance_methods(_, receiver, include_super_obj = TrueObject::TRUE)
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          collect = lambda do |mod|
            mod.methods_table.each do |name, m|
              next if seen[name]
              seen[name] = true
              next if m == ModuleObject::UNDEF_SENTINEL
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

        def module_protected_instance_methods(_, receiver, include_super_obj = TrueObject::TRUE)
          include_super = include_super_obj.truthy?
          seen = {}
          result = []
          collect = lambda do |mod|
            mod.methods_table.each do |name, m|
              next if seen[name]
              seen[name] = true
              next if m == ModuleObject::UNDEF_SENTINEL
              result << SymbolObject.from(name) if m.visibility == :protected
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

        def module_instance_method(context, receiver, name_obj)
          name = sym_name_coercing(context, name_obj)
          # Check active refinements first (refinements shadow regular methods for instance_method).
          # Refinements active at the CALL SITE take priority — the method itself (instance_method)
          # has no stored refinements, so check the caller's frame (parent_frame) for using-activated refinements.
          active_refs = caller_active_refinements(context)
          if active_refs && !active_refs.empty?
            receiver.ancestors_list.each do |ancestor|
              ref_mod = active_refs[ancestor.object_id]
              if ref_mod
                ref_m = ref_mod.get_method(name)
                if ref_m && ref_m != ModuleObject::UNDEF_SENTINEL
                  owner = ref_m.is_a?(Method) && ref_m.original_owner ? ref_m.original_owner : ref_mod
                  return UnboundMethodObject.new(ref_m, name, owner)
                end
              end
            end
          end
          m = receiver.lookup_method(name)
          if m.nil? || m == ModuleObject::UNDEF_SENTINEL
            exc = FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
            exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
            raise exc
          end
          owner = receiver.lookup_method_owner(name) || receiver
          UnboundMethodObject.new(m, name, owner)
        end

        def module_public_instance_method(context, receiver, name_obj)
          name = sym_name_coercing(context, name_obj)
          m = receiver.lookup_method(name)
          if m.nil? || m == ModuleObject::UNDEF_SENTINEL
            exc = FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
            exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
            raise exc
          end
          unless m.visibility == :public
            exc = FrozoneException.make(:NameError, "method '#{name}' for class '#{receiver.name}' is #{m.visibility}")
            exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
            raise exc
          end
          owner = receiver.lookup_method_owner(name) || receiver
          UnboundMethodObject.new(m, name, owner)
        end

        def object_method(context, receiver, name_obj)
          name = sym_name(name_obj)
          # Check active refinements first — `method(:foo)` with refinements active should find refined methods
          active_refinements = context&.frame&.active_refinements
          m = if active_refinements && !active_refinements.empty?
            receiver.lookup_method_with_refinements(name, active_refinements)
          else
            klass = receiver.eigenclass || receiver.class_object
            klass.lookup_method(name) || receiver.class_object.lookup_method(name)
          end
          unless m
            # Check respond_to_missing?
            rtm = begin
              receiver.dispatch(context, :respond_to_missing?, [SymbolObject.from(name), TrueObject::TRUE], {}, nil, private_ok: true)
            rescue FrozoneException
              FalseObject::FALSE
            end
            if rtm.truthy?
              owner = receiver.class_object
              bm = BoundMethodObject.new(nil, name, receiver, owner)
              bm.method_missing_dispatch = true
              return bm
            end
            raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.class_object.full_name}'")
          end
          # If the eigenclass has the method (directly or via extended modules), use eigenclass chain for owner
          if receiver.eigenclass&.lookup_method(name)
            owner = receiver.eigenclass.lookup_method_owner(name) || receiver.eigenclass
          else
            owner = receiver.class_object.lookup_method_owner(name) || receiver.class_object
          end
          BoundMethodObject.new(m, name, receiver, owner)
        end

        def object_public_method(context, receiver, name_obj)
          name = sym_name(name_obj)
          active_refinements = context&.frame&.active_refinements
          m = if active_refinements && !active_refinements.empty?
            receiver.lookup_method_with_refinements(name, active_refinements)
          else
            klass = receiver.eigenclass || receiver.class_object
            klass.lookup_method(name) || receiver.class_object.lookup_method(name)
          end
          unless m
            raise FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.class_object.full_name}'")
          end
          vis = m.respond_to?(:visibility) ? m.visibility : :public
          unless vis == :public
            raise FrozoneException.make(:NameError, "method '#{name}' for class '#{receiver.class_object.full_name}' is #{vis}")
          end
          if receiver.eigenclass&.lookup_method(name)
            owner = receiver.eigenclass.lookup_method_owner(name) || receiver.eigenclass
          else
            owner = receiver.class_object.lookup_method_owner(name) || receiver.class_object
          end
          BoundMethodObject.new(m, name, receiver, owner)
        end

        def bound_method_call(context, receiver, args, kwargs)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          blk = context.frame.block
          blk = nil if blk.nil? || blk.is_a?(NilObject)
          kw = kwargs.is_a?(HashObject) ? kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k.raw.to_sym } : {}
          if receiver.method_missing_dispatch
            receiver.bound_receiver.dispatch(context, :method_missing, [SymbolObject.from(receiver.bound_name)] + args.raw, kw, blk, private_ok: true)
          elsif receiver.raw_method
            # Directly invoke the captured method, bypassing normal lookup (correct for UnboundMethod.bind.call)
            receiver.raw_method.invoke(context, receiver.bound_receiver, args.raw, kw, blk)
          else
            receiver.bound_receiver.dispatch(context, receiver.bound_name, args.raw, kw, blk)
          end
        end

        def bound_method_arity(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          return IntegerObject.new(-1) unless m  # method_missing synthetic method
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
        ANON_REQ     = :__anon_req__

        # Returns nil to indicate the parameter is anonymous (no name in output)
        # ANON_REST maps to :* for both methods and procs (anonymous splat shows as *)
        def normalize_param_name(sym, for_proc: false)
          case sym
          when ANON_REQ                           then nil
          when ANON_REST                          then :*
          when :__forward_args__                  then :*
          when ANON_KWARGS, :__forward_kwargs__   then :**
          when ANON_BLOCK, :__forward_block__     then :&
          when /\A__(?:repeated|discard)_\w+__\z/  then :_
          when Hash                               then nil  # multi-target destructuring: no name
          else sym
          end
        end

        def param_entry(type, name, for_proc: false)
          n = normalize_param_name(name, for_proc: for_proc)
          n ? ArrayObject.new([SymbolObject.from(type), SymbolObject.from(n)]) : ArrayObject.new([SymbolObject.from(type)])
        end

        def extract_method_params(m)
          # Resolve DefinedMethod to its underlying block_obj
          m = m.block_obj if m.is_a?(DefinedMethod)
          return [] unless m.is_a?(BlockObject) || m.is_a?(Method)
          params = []
          m.required_params.each { |p| params << param_entry(:req, p) }
          m.optional_params.each { |p, _| params << param_entry(:opt, p) }
          if m.rest_param && m.rest_param != :__no_rest__
            params << param_entry(:rest, m.rest_param)
          end
          m.post_params.each { |p| params << param_entry(:req, p) }
          m.required_kw_params.each { |p| params << ArrayObject.new([SymbolObject.from(:keyreq), SymbolObject.from(p)]) }
          m.optional_kw_params.each { |p, _| params << ArrayObject.new([SymbolObject.from(:key), SymbolObject.from(p)]) }
          if m.kw_rest_param == :__no_kwargs__
            params << ArrayObject.new([SymbolObject.from(:nokey)])
          elsif m.kw_rest_param
            params << param_entry(:keyrest, m.kw_rest_param)
          end
          if m.block_param
            params << param_entry(:block, m.block_param)
          end
          params
        end

        def bound_method_parameters(_, receiver)
          return ArrayObject.new([]) unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          return ArrayObject.new([ArrayObject.new([SymbolObject.from(:rest)])]) if m.nil?
          ArrayObject.new(extract_method_params(m))
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

        FROZONE_CORE_LIB = File.expand_path('../../core', __dir__).freeze

        def bound_method_source_location(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          # Resolve VisibilityOverride to the underlying method
          m = m.original_owner.lookup_method(m.method_name) if m.is_a?(ModuleObject::VisibilityOverride)
          m = m.block_obj if m.is_a?(DefinedMethod)
          if m.is_a?(Method) && m.source_location
            file, line = m.source_location.split(":")
            if file.start_with?(FROZONE_CORE_LIB)
              rel = file[FROZONE_CORE_LIB.length + 1..]
              ArrayObject.new([StringObject.new("<internal:#{rel}>"), IntegerObject.new(line.to_i)])
            else
              ArrayObject.new([StringObject.new(file), IntegerObject.new(line.to_i)])
            end
          elsif m.is_a?(BlockObject) && m.source_location
            file, line = m.source_location
            ArrayObject.new([StringObject.new(file), IntegerObject.new(line)])
          else
            NilObject::NIL
          end
        end

        def bound_method_dup(_, receiver, freeze_opt = NilObject::NIL)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          copy = BoundMethodObject.new(receiver.raw_method, receiver.bound_name, receiver.bound_receiver, receiver.bound_owner)
          frozen = freeze_opt.is_a?(NilObject) ? false : freeze_opt.truthy?
          copy.copy_fields_from(receiver, eigenclass: nil, frozen: frozen)
          copy
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
          recv = receiver.bound_receiver
          # Determine the lookup class: eigenclass (for extended objects) or class_object
          lookup_klass = recv.is_a?(ObjectObject) ? (recv.eigenclass || recv.class_object) : nil
          lookup_klass ||= owner.is_a?(ClassObject) ? owner : nil
          return NilObject::NIL unless lookup_klass&.respond_to?(:lookup_method_after)
          # For aliased methods, the raw Method preserves its original name (alias_as keeps @name).
          # Use that original name for the ancestor lookup so we find the right super method.
          orig_raw = receiver.raw_method
          # VisibilityOverride: the actual method lives in original_owner under method_name.
          # Use those for lookup so super skips the module where the override was created.
          if orig_raw.is_a?(ModuleObject::VisibilityOverride)
            lookup_name = orig_raw.method_name
            origin = orig_raw.original_owner
          else
            lookup_name = orig_raw.is_a?(Method) ? orig_raw.name : receiver.bound_name
            raw = orig_raw.is_a?(DefinedMethod) ? orig_raw.block_obj : orig_raw
            # For visibility-changed methods, the raw_method has original_owner pointing to
            # the actual defining class. Use that as the origin for super lookup so we skip
            # over the visibility wrapper stored in owner's class.
            origin = (raw.is_a?(Method) && raw.original_owner) || owner
          end
          m = lookup_klass.lookup_method_after(lookup_name, origin)
          return NilObject::NIL unless m
          super_owner = lookup_klass.lookup_method_owner_after(lookup_name, origin) || lookup_klass
          BoundMethodObject.new(m, lookup_name, recv, super_owner)
        end

        def bound_method_to_proc(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          ProcObject.new(receiver, lambda: true)
        end

        def bound_method_eql(_, m1, m2)
          return FalseObject::FALSE unless m1.is_a?(BoundMethodObject) && m2.is_a?(BoundMethodObject)
          return FalseObject::FALSE unless m1.bound_receiver.equal?(m2.bound_receiver)
          m1m = m1.raw_method; m2m = m2.raw_method
          # Methods are equal if they share the same implementation body/block
          same = if m1m.nil? && m2m.nil?
            # Both are method_missing synthetic methods: compare by name
            m1.bound_name == m2.bound_name
          elsif m1m.is_a?(Method) && m2m.is_a?(Method)
            m1m.equal?(m2m) || m1m.body.equal?(m2m.body)
          elsif m1m.is_a?(DefinedMethod) && m2m.is_a?(DefinedMethod)
            m1m.equal?(m2m) || m1m.block_obj.equal?(m2m.block_obj)
          else
            m1m.equal?(m2m)
          end
          same ? TrueObject::TRUE : FalseObject::FALSE
        end

        def unbound_method_eq(_, a, b)
          return FalseObject::FALSE unless a.is_a?(UnboundMethodObject) && b.is_a?(UnboundMethodObject)
          same = a.unbound_owner.equal?(b.unbound_owner) &&
                 a.unbound_name == b.unbound_name &&
                 a.raw_method.equal?(b.raw_method)
          bool_object_for(same)
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
          # Resolve VisibilityOverride to underlying method
          m = m.original_owner.lookup_method(m.method_name) if m.is_a?(ModuleObject::VisibilityOverride)
          m = m.block_obj if m.is_a?(DefinedMethod)
          if m.is_a?(Method) && m.source_location
            file, line = m.source_location.split(":")
            if file.start_with?(FROZONE_CORE_LIB)
              rel = file[FROZONE_CORE_LIB.length + 1..]
              ArrayObject.new([StringObject.new("<internal:#{rel}>"), IntegerObject.new(line.to_i)])
            else
              ArrayObject.new([StringObject.new(file), IntegerObject.new(line.to_i)])
            end
          elsif m.is_a?(BlockObject) && m.source_location
            file, line = m.source_location
            ArrayObject.new([StringObject.new(file), IntegerObject.new(line)])
          else
            NilObject::NIL
          end
        end

        def unbound_method_super(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          owner = receiver.unbound_owner
          return NilObject::NIL unless owner&.respond_to?(:lookup_method_after)
          orig_raw = receiver.raw_method
          if orig_raw.is_a?(ModuleObject::VisibilityOverride)
            lookup_name = orig_raw.method_name
            origin = orig_raw.original_owner
          else
            lookup_name = orig_raw.is_a?(Method) ? orig_raw.name : receiver.unbound_name
            raw = orig_raw.is_a?(DefinedMethod) ? orig_raw.block_obj : orig_raw
            origin = (raw.is_a?(Method) && raw.original_owner) || owner
          end
          m = owner.lookup_method_after(lookup_name, origin)
          return NilObject::NIL unless m
          super_owner = owner.lookup_method_owner_after(lookup_name, origin) || owner
          UnboundMethodObject.new(m, lookup_name, super_owner)
        end

        def unbound_method_dup(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          copy = UnboundMethodObject.new(receiver.raw_method, receiver.unbound_name, receiver.unbound_owner)
          receiver.instance_variables_hash.each do |ivar, val|
            copy.set_ivar(ivar, val)
          end
          copy
        end

        def unbound_method_hash(_, receiver)
          return IntegerObject.new(0) unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          body_id = if m.is_a?(Method)
            m.body.object_id
          elsif m.is_a?(DefinedMethod)
            m.block_obj.object_id
          else
            m.object_id
          end
          IntegerObject.new(receiver.unbound_owner.object_id ^ body_id)
        end

        def unbound_method_bind(_, receiver, new_receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          owner = receiver.unbound_owner
          if owner.is_a?(ClassObject) && owner.is_singleton_class
            # Singleton class method: check based on what the singleton belongs to
            orig = owner.singleton_of
            if orig.is_a?(ClassObject)
              # Class singleton method: bindable to the same class or subclasses
              unless new_receiver.is_a?(ClassObject) && subclass_of_builtin?(new_receiver, orig)
                raise FrozoneException.make(:TypeError, "singleton method called for a different object")
              end
            else
              # Instance singleton method: only bindable to the exact original object
              unless new_receiver.equal?(orig)
                raise FrozoneException.make(:TypeError, "singleton method called for a different object")
              end
            end
          elsif owner.is_a?(ClassObject)
            # Class method: new_receiver must be kind_of? the owner class
            unless new_receiver.is_a?(ObjectObject) && subclass_of_builtin?(new_receiver.class_object, owner)
              raise FrozoneException.make(:TypeError, "bind argument must be an instance of #{owner.name}")
            end
          end
          # Module methods: any receiver allowed
          BoundMethodObject.new(receiver.raw_method, receiver.unbound_name, new_receiver, receiver.unbound_owner)
        end

        def unbound_method_owner(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          receiver.unbound_owner
        end

        # Check if a method (UnboundMethodObject) is "defined in Ruby code" (not an intrinsic).
        # A method with an IntrinsicCall body is considered NOT defined in Ruby code.
        # Returns true if the method body consists entirely of IntrinsicCall node(s).
        # A Sequence with one IntrinsicCall, or a bare IntrinsicCall, both count as intrinsic.
        def intrinsic_only_body?(body)
          case body
          when Ast::IntrinsicCall
            true
          when Ast::Sequence
            body.nodes.size == 1 && body.nodes.first.is_a?(Ast::IntrinsicCall)
          else
            false
          end
        end

        # Check if a method (UnboundMethodObject) is "defined in Ruby code" (not an intrinsic).
        # A method whose body is a bare IntrinsicCall (or a Sequence wrapping one) is NOT Ruby code.
        def method_ruby_defined_q(_, receiver)
          return FalseObject::FALSE unless receiver.is_a?(UnboundMethodObject)
          m = receiver.raw_method
          return FalseObject::FALSE unless m.is_a?(Method)
          body = m.body
          return FalseObject::FALSE if intrinsic_only_body?(body)
          TrueObject::TRUE
        end

        # Copy an UnboundMethod into a refinement module as an owned method.
        # Sets refining_module so the imported method can see other refinements from the same module.
        # Updates scopes so that super() resolves through the refinement module's refined class.
        def refinement_import_method(_, refinement, name_obj, unbound_method_obj)
          return NilObject::NIL unless refinement.is_a?(ModuleObject)
          return NilObject::NIL unless unbound_method_obj.is_a?(UnboundMethodObject)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.to_s.to_sym
          raw_m = unbound_method_obj.raw_method
          # Use refinement as the last scope so super resolves through the refinement's class hierarchy.
          new_scopes = (raw_m.scopes || []).dup
          if new_scopes.empty?
            new_scopes = [refinement]
          else
            new_scopes[-1] = refinement
          end
          imported = Method.new(
            new_scopes, name, raw_m.required_params, raw_m.optional_params, raw_m.rest_param,
            raw_m.post_params, raw_m.required_kw_params, raw_m.optional_kw_params, raw_m.kw_rest_param,
            raw_m.block_param, raw_m.locals, raw_m.body,
            uses_block: raw_m.uses_block, source_location: raw_m.source_location
          )
          imported.visibility = raw_m.visibility
          imported.original_owner = refinement
          # Link to the containing refinement module so this method sees other refinements
          refining_mod = refinement.get_ivar(:@__refining_module__)
          imported.refining_module = refining_mod if refining_mod.is_a?(ModuleObject)
          refinement.set_method(name, imported)
          NilObject::NIL
        end

        def module_private_method_defined(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name_coercing(context, name_obj)
          inherit = inherit_obj.truthy?
          m = inherit ? receiver.lookup_method(name) : receiver.get_method(name)
          m && m != ModuleObject::UNDEF_SENTINEL && m.visibility == :private ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_public_method_defined(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name_coercing(context, name_obj)
          inherit = inherit_obj.truthy?
          m = inherit ? receiver.lookup_method(name) : receiver.get_method(name)
          m && m != ModuleObject::UNDEF_SENTINEL && m.visibility == :public ? TrueObject::TRUE : FalseObject::FALSE
        end

        def module_protected_method_defined(context, receiver, name_obj, inherit_obj = TrueObject::TRUE)
          name = sym_name_coercing(context, name_obj)
          inherit = inherit_obj.truthy?
          m = inherit ? receiver.lookup_method(name) : receiver.get_method(name)
          m && m != ModuleObject::UNDEF_SENTINEL && m.visibility == :protected ? TrueObject::TRUE : FalseObject::FALSE
        end

        def trigger_method_added(context, receiver, name)
          return unless context  # Guard against bootstrap-time calls without context
          if receiver.is_a?(ClassObject) && receiver.is_singleton_class && receiver.singleton_of
            # Adding to a singleton class → call singleton_method_added on original object
            orig = receiver.singleton_of
            orig.dispatch(context, :singleton_method_added, [SymbolObject.from(name)], {}, nil, private_ok: true)
          else
            # Regular class/module → call method_added on the class/module itself
            receiver.dispatch(context, :method_added, [SymbolObject.from(name)], {}, nil, private_ok: true)
          end
        rescue FrozoneException
          raise  # propagate Frozone exceptions (e.g. NoMethodError when hook is undefined)
        rescue StandardError
          # Suppress MRI-level errors (e.g. during boot when Frozone VM not fully set up)
        end

        def module_display_name(context, receiver)
          if receiver.is_a?(ClassObject) && receiver.is_singleton_class
            attached = receiver.singleton_of
            if attached.is_a?(ModuleObject)
              attached_name = attached.full_name
              attached_name ? attached_name.to_s : begin
                receiver.dispatch(context, :to_s, [], {}).raw rescue "#<Class>"
              end
            else
              begin
                s = receiver.dispatch(context, :to_s, [], {})
                s.is_a?(StringObject) ? s.raw : s.to_s
              rescue FrozoneException, StandardError
                "#<Class>"
              end
            end
          else
            (receiver.is_a?(ModuleObject) ? receiver.full_name : nil)&.to_s || receiver.class.name
          end
        end

        def trigger_method_removed(context, receiver, name)
          return unless context
          if receiver.is_a?(ClassObject) && receiver.is_singleton_class && receiver.singleton_of
            orig = receiver.singleton_of
            orig.dispatch(context, :singleton_method_removed, [SymbolObject.from(name)], {}, nil, private_ok: true)
          else
            receiver.dispatch(context, :method_removed, [SymbolObject.from(name)], {}, nil, private_ok: true)
          end
        rescue FrozoneException
          raise
        rescue StandardError
        end

        def trigger_method_undefined(context, receiver, name)
          return unless context
          if receiver.is_a?(ClassObject) && receiver.is_singleton_class && receiver.singleton_of
            orig = receiver.singleton_of
            orig.dispatch(context, :singleton_method_undefined, [SymbolObject.from(name)], {}, nil, private_ok: true)
          else
            receiver.dispatch(context, :method_undefined, [SymbolObject.from(name)], {}, nil, private_ok: true)
          end
        rescue FrozoneException
          raise
        rescue StandardError
        end

        def coerce_attr_name(context, name_obj)
          if name_obj.is_a?(SymbolObject)
            name_obj.raw
          elsif name_obj.is_a?(StringObject)
            name_obj.raw.to_sym
          else
            type_name = name_obj.is_a?(ObjectObject) ? name_obj.class_object&.name : name_obj.class.name
            has_to_str = begin
              name_obj.dispatch(context, :respond_to?, [SymbolObject.from(:to_str)], {}).truthy?
            rescue FrozoneException
              false
            end
            raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string") unless has_to_str
            result = name_obj.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string") unless result.is_a?(StringObject)
            result.raw.to_sym
          end
        end

        def module_attr_reader(context, receiver, names)
          result = names.raw.map do |name_obj|
            name = coerce_attr_name(context, name_obj)
            ivar = :"@#{name}"
            body = Ast::InstanceVariableRead.new(ivar)
            m = Method.new([receiver], name, [], [], nil, [], [], [], nil, nil, [], body)
            m.visibility = receiver.current_visibility
            receiver.set_method(name, m)
            trigger_method_added(context, receiver, name)
            SymbolObject.from(name)
          end
          ArrayObject.new(result)
        end

        def module_attr_writer(context, receiver, names)
          result = names.raw.map do |name_obj|
            name = coerce_attr_name(context, name_obj)
            setter = :"#{name}="
            ivar = :"@#{name}"
            body = Ast::InstanceVariableWrite.new(ivar, Ast::LocalVariableRead.new(ANON_REQ, 0))
            m = Method.new([receiver], setter, [ANON_REQ], [], nil, [], [], [], nil, nil, [ANON_REQ], body)
            m.visibility = receiver.current_visibility
            receiver.set_method(setter, m)
            trigger_method_added(context, receiver, setter)
            SymbolObject.from(setter)
          end
          ArrayObject.new(result)
        end

        def module_attr_accessor(context, receiver, names)
          result = names.raw.flat_map do |name_obj|
            name = coerce_attr_name(context, name_obj)
            setter = :"#{name}="
            ivar = :"@#{name}"
            reader_body = Ast::InstanceVariableRead.new(ivar)
            rm = Method.new([receiver], name, [], [], nil, [], [], [], nil, nil, [], reader_body)
            rm.visibility = receiver.current_visibility
            receiver.set_method(name, rm)
            trigger_method_added(context, receiver, name)
            writer_body = Ast::InstanceVariableWrite.new(ivar, Ast::LocalVariableRead.new(ANON_REQ, 0))
            wm = Method.new([receiver], setter, [ANON_REQ], [], nil, [], [], [], nil, nil, [ANON_REQ], writer_body)
            wm.visibility = receiver.current_visibility
            receiver.set_method(setter, wm)
            trigger_method_added(context, receiver, setter)
            [SymbolObject.from(name), SymbolObject.from(setter)]
          end
          ArrayObject.new(result)
        end

        def module_set_public(context, receiver, names)    = module_set_visibility(context, receiver, names, :public)
        def module_set_private(context, receiver, names)   = module_set_visibility(context, receiver, names, :private)
        def module_set_protected(context, receiver, names) = module_set_visibility(context, receiver, names, :protected)

        def module_set_class_method_visibility(context, receiver, names_obj, vis)
          sc = receiver.singleton_class
          # vis may come from Frozone-land as a SymbolObject — coerce to raw Symbol
          vis_sym = vis.is_a?(SymbolObject) ? vis.raw : vis
          # Handle array as single argument: private_class_method([:foo, :bar]) → flatten
          name_list = if names_obj.is_a?(ArrayObject)
            nl = names_obj.raw
            nl.size == 1 && nl[0].is_a?(ArrayObject) ? nl[0].raw : nl
          else
            [names_obj]
          end
          name_list.each do |name_obj|
            name = sym_name_coercing(context, name_obj)
            m = sc.get_method(name)
            if m.nil? || m == ModuleObject::UNDEF_SENTINEL
              orig_owner = receiver.lookup_instance_method(name)&.tap { |_| nil } && sc.lookup_method_owner(name)
              # Walk singleton class hierarchy for the method
              found = nil
              sc_walk = sc
              while sc_walk
                fm = sc_walk.get_method(name)
                if fm && fm != ModuleObject::UNDEF_SENTINEL
                  found = [fm, sc_walk]
                  break
                end
                sc_walk = sc_walk.is_a?(ClassObject) ? sc_walk.superclass : nil
              end
              if found.nil?
                exc = FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
                exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
                raise exc
              end
              inherited_m, orig_sc = found
              m = inherited_m.dup_with_visibility(vis_sym, original_owner: orig_sc.equal?(sc) ? nil : orig_sc)
              sc.set_method(name, m)
            else
              m.visibility = vis_sym
            end
          end
          receiver
        end

        def module_function(context, receiver, names)
          raise FrozoneException.make(:TypeError, "module_function is not permitted on classes") if receiver.is_a?(ClassObject)
          name_list = names.is_a?(ArrayObject) ? names.raw : [names]
          if name_list.empty?
            receiver.current_visibility = :module_function
            return NilObject::NIL
          end
          result_names = name_list.map do |name_obj|
            name = sym_name_coercing(context, name_obj)
            m = receiver.get_method(name) || receiver.lookup_method(name) ||
                Core::OBJECT_CLASS.lookup_method(name)
            unless m.nil? || m == ModuleObject::UNDEF_SENTINEL
              # Add as private instance method (don't call method_added — just adjusting visibility)
              m.visibility = :private
              receiver.set_method(name, m)
              # Add as public singleton method (bound to singleton class for super resolution)
              sm = m.respond_to?(:bound_copy) ? m.bound_copy(name, receiver.singleton_class) : m.dup
              sm.visibility = :public
              receiver.singleton_class.set_method(name, sm)
              # Only call singleton_method_added (not method_added) for the copy
              trigger_method_added(context, receiver.singleton_class, name)
            end
            SymbolObject.from(name)
          end
          # Return single symbol or array of symbols
          result_names.size == 1 ? result_names[0] : ArrayObject.new(result_names)
        end

        # Top-level 'main' proxy: delegate to Object
        def toplevel_public(context, _, names)    = module_set_visibility(context, Core::OBJECT_CLASS, names, :public)
        def toplevel_private(context, _, names)   = module_set_visibility(context, Core::OBJECT_CLASS, names, :private)
        def toplevel_protected(context, _, names) = module_set_visibility(context, Core::OBJECT_CLASS, names, :protected)

        # main.define_method(name, callable_or_nil, &block) → delegates to Object.define_method
        # args_array collects [name] or [name, callable]; block is the block arg.
        def toplevel_define_method(context, _, args_array, block)
          args = args_array.raw
          name_obj = args[0]
          callable = args.length > 1 ? args[1] : nil
          effective = if callable.nil? || callable.is_a?(NilObject)
            block
          else
            callable
          end
          unless effective && !effective.is_a?(NilObject)
            raise FrozoneException.make(:ArgumentError, "tried to create Proc object without a block")
          end
          # top-level define_method always creates a public method on Object
          # (unlike module context where current_visibility applies)
          prev_vis = Core::OBJECT_CLASS.current_visibility
          Core::OBJECT_CLASS.current_visibility = :public
          begin
            module_define_method(context, Core::OBJECT_CLASS, name_obj, effective)
          ensure
            Core::OBJECT_CLASS.current_visibility = prev_vis
          end
        end

        def toplevel_ruby2_keywords(context, _, names)
          module_ruby2_keywords(context, Core::OBJECT_CLASS, names)
        end

        def toplevel_using(context, _receiver, mod_array)
          mod = mod_array.raw.first
          raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given 0, expected 1)") if mod.nil?
          module_using(context, _receiver, mod)
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

        def kernel_integer(context, _receiver, val, base, exception = nil)
          exc = exception.nil? || exception.is_a?(NilObject) || exception.truthy?
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
            rescue FrozoneException => e
              raise if exc
              return NilObject::NIL
            end
          end
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

        def kernel_load(_, _receiver, path_obj, wrap_obj = nil)
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
          # No block given
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

        def proc_parameters(_, proc_obj, lambda_override = NilObject::NIL)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk.is_a?(NativeBlock) && blk.parameters_override
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
            if kw_rest == :__no_kwargs__
              params << ArrayObject.new([SymbolObject.from(:nokey)])
            else
              params << param_entry(:keyrest, kw_rest, for_proc: true)
            end
          end
          params << param_entry(:block, blk_param, for_proc: true) if blk_param
          ArrayObject.new(params)
        end

        def proc_source_location(context, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          if blk.is_a?(BlockObject) || blk.is_a?(NativeBlock)
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

        def kernel_binding(context, _receiver)
          # Capture the calling frame (frames[-2] since we're inside a kernel method call).
          captured_frame = context.frames.length >= 2 ? context.frames[-2] : context.frame
          # Source location: where `binding` was called (context.call_site set by MethodCall.evaluate)
          binding_call_site = context.call_site || captured_frame&.incoming_call_site
          BindingObject.new(captured_frame, binding_call_site)
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

        def binding_receiver(_, binding_obj)
          binding_obj.captured_frame.the_self
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

        def binding_all_locals(frame)
          names = []
          f = frame
          while f
            # If frame has own_locals set (eval frame), use only those for this level.
            # Parent frame walk handles inherited locals.
            locals_here = f.own_locals || f.local_names
            locals_here.each { |n| names << n unless names.include?(n) }
            f = f.parent_frame
          end
          names
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
          bool_object_for(binding_obj.binding_local_names.include?(name))
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

        # Class
        def class_new(context, klass, args, kwargs, block = nil)
          raise FrozoneException.make(:TypeError, "can't create instance of singleton class") if klass.is_singleton_class
          raise FrozoneException.make(:TypeError, "uninitialized class") if klass.is_a?(ClassObject) && klass.uninitialized_class
          raw_args = args.raw
          raw_kwargs = kwargs.raw.transform_keys { |k| k.is_a?(SymbolObject) ? k.raw : k }
          has_block = block && !block.is_a?(NilObject)
          if klass.equal?(Core::CLASS_CLASS)
            sc_arg = raw_args.first
            if sc_arg && !sc_arg.is_a?(NilObject)
              raise FrozoneException.make(:TypeError, "superclass must be a Class (#{sc_arg.class_object&.name || sc_arg.class} given)") unless sc_arg.is_a?(ClassObject)
              raise FrozoneException.make(:TypeError, "can't make subclass of singleton class") if sc_arg.is_singleton_class
              superclass = sc_arg
            else
              superclass = Core::OBJECT_CLASS
            end
            new_class = ClassObject.new(nil, nil, superclass)
            # Call inherited hook before block runs (MRI behavior)
            begin
              superclass.dispatch(context, :inherited, [new_class], {}, nil, private_ok: true)
            rescue FrozoneException => e
              raise unless e.frozone_class_name == :NoMethodError
            end
            if has_block
              prev_vis = new_class.current_visibility
              new_class.current_visibility = :public
              begin
                block.invoke(context, [new_class], receiver: new_class, def_scope: new_class)
              ensure
                new_class.current_visibility = prev_vis
              end
            end
            return new_class
          elsif klass.equal?(Core::MODULE_CLASS) || klass.equal?(Core::REFINEMENT_CLASS)
            new_mod = ModuleObject.new(nil, nil, klass)
            if has_block
              prev_vis = new_mod.current_visibility
              new_mod.current_visibility = :public
              begin
                block.invoke(context, [new_mod], receiver: new_mod, def_scope: new_mod)
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
          if klass.equal?(Core::MODULE_CLASS)
            raise FrozoneException.make(:TypeError, "can't create instance of virtual class")
          end
          if klass.equal?(Core::CLASS_CLASS)
            # Class.allocate returns an uninitialized Class instance (no superclass set)
            uninit = ClassObject.new(nil, nil, nil)
            uninit.uninitialized_class = true
            return uninit
          end
          klass.allocate_instance
        end

        def class_superclass(_, klass)
          raise FrozoneException.make(:TypeError, "uninitialized class") if klass.is_a?(ClassObject) && klass.uninitialized_class
          sc = klass.is_a?(ClassObject) ? klass.superclass : nil
          sc.nil? ? NilObject::NIL : sc
        end

        def class_subclasses(_, klass)
          return ArrayObject.new([]) unless klass.is_a?(ClassObject)
          ArrayObject.new(klass.direct_subclasses)
        end

        # Returns the safe string representation of a singleton class's target without dispatching inspect/to_s
        def module_singleton_class_safe_target_str(_, receiver)
          target = receiver.singleton_of
          return StringObject.new("") unless target
          if target.is_a?(ModuleObject)
            n = target.full_name
            s = n ? n.to_s : "#<#{target.is_a?(ClassObject) ? 'Class' : 'Module'}:0x#{target.object_id.to_s(16)}>"
            StringObject.new(s)
          else
            klass = target.class_object
            # Match Object#to_s: use class.to_s (full_name for named, #<Class:0x...> for anonymous)
            class_str = klass ? (klass.name ? klass.full_name.to_s : "#<Class:0x#{klass.object_id.to_s(16)}>") : ""
            StringObject.new("#<#{class_str}:0x#{target.object_id.to_s(16)}>")
          end
        end

        def class_attached_object(_, klass)
          unless klass.is_a?(ClassObject) && klass.is_singleton_class && klass.singleton_of
            name = klass.is_a?(ClassObject) ? (klass.name&.to_s || klass.inspect) : klass.inspect
            raise FrozoneException.make(:TypeError, "`#{name}' is not a singleton class")
          end
          klass.singleton_of
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
            if v.is_a?(ClassObject)
              c = v.superclass
              while c
                sources << c.eigenclass if c.eigenclass
                c = c.is_a?(ClassObject) ? c.superclass : nil
              end
            end
            c = v.class_object
            while c
              sources << c
              c.modules.reverse_each { |m| sources << m }
              c = c.is_a?(ClassObject) ? c.superclass : nil
            end
          # include_super=false: only singleton class's own methods (no class_object methods)
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

        def module_set_visibility(context, receiver, names, vis)
          name_list = names.raw
          if name_list.empty?
            receiver.current_visibility = vis
            return NilObject::NIL
          end
          # Handle array as single argument: private([:foo, :bar]) → flatten one level
          if name_list.size == 1 && name_list[0].is_a?(ArrayObject)
            name_list = name_list[0].raw
          end
          result = name_list.map do |name_obj|
            name = sym_name_coercing(context, name_obj)
            m = receiver.get_method(name)
            if m.nil? || m == ModuleObject::UNDEF_SENTINEL
              orig_owner = receiver.lookup_method_owner(name)
              # Also search Object as fallback (for Kernel reopenings that reference Object methods)
              orig_owner ||= Core::OBJECT_CLASS.lookup_method_owner(name)
              inherited_m = orig_owner&.get_method(name)
              if inherited_m.nil? || inherited_m == ModuleObject::UNDEF_SENTINEL
                exc = FrozoneException.make(:NameError, "undefined method '#{name}' for class '#{receiver.name}'")
                exc.vm_object.set_ivar(:@name, SymbolObject.from(name))
                raise exc
              end
              # Use VisibilityOverride instead of copying the method body.
              # This ensures that if the parent later redefines the method, the child still sees the new implementation.
              unless inherited_m.visibility == vis
                override = ModuleObject::VisibilityOverride.new(vis, orig_owner, name)
                receiver.set_method(name, override)
                trigger_method_added(context, receiver, name)
              end
            else
              m.visibility = vis
            end
            SymbolObject.from(name)
          end
          result.size == 1 ? result[0] : ArrayObject.new(result)
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

        # ObjectSpace

        def objectspace_each_object(context, klass_obj, block)
          return IntegerObject.new(0) if block.nil? || block.is_a?(NilObject)
          klass = klass_obj.is_a?(NilObject) ? nil : klass_obj
          count = 0
          ::ObjectSpace.each_object(Frozone::Vm::ObjectObject) do |obj|
            next if klass && object_is_a(context, obj, klass).equal?(FalseObject::FALSE)
            block.invoke(context, [obj])
            count += 1
          end
          IntegerObject.new(count)
        rescue StandardError
          IntegerObject.new(0)
        end

        def objectspace_define_finalizer(context, obj, proc_arg, block)
          # Non-reference objects (immediate values) cannot have finalizers
          if obj.is_a?(IntegerObject) || obj.is_a?(SymbolObject) || obj.is_a?(NilObject) ||
             obj.is_a?(TrueObject) || obj.is_a?(FalseObject)
            klass = obj.respond_to?(:class_object) ? (obj.class_object&.name || obj.class) : obj.class
            raise FrozoneException.make(:ArgumentError, "wrong argument type #{klass} (expected non-immediate)")
          end
          callable = if !block.nil? && !block.is_a?(NilObject)
            block
          elsif !proc_arg.nil? && !proc_arg.is_a?(NilObject)
            proc_arg
          else
            raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given 1, expected 2)")
          end
          # Check respond_to?(:call)
          responds = begin
            result = callable.dispatch(context, :respond_to?, [SymbolObject.from(:call)], {})
            result.equal?(TrueObject::TRUE)
          rescue FrozoneException
            callable.respond_to?(:invoke)
          end
          unless responds
            klass = callable.respond_to?(:class_object) ? (callable.class_object&.name || callable.class) : callable.class
            raise FrozoneException.make(:ArgumentError, "wrong argument type #{klass} (expected Proc)")
          end
          # Return [0, proc] as MRI does
          ArrayObject.new([IntegerObject.new(0), callable])
        end

        def objectspace_garbage_collect(_)
          ::GC.start
          NilObject::NIL
        end

        def objectspace_undefine_finalizer(context, obj)
          is_frozen = begin
            obj.dispatch(context, :frozen?, [], {}).equal?(TrueObject::TRUE)
          rescue FrozoneException
            false
          end
          if is_frozen
            klass_name = obj.respond_to?(:class_object) ? (obj.class_object&.name || 'Object') : 'Object'
            raise FrozoneException.make(:FrozenError, "can't modify frozen #{klass_name}")
          end
          obj
        end

        def objectspace_id2ref(_, id_obj)
          id = id_obj.is_a?(IntegerObject) ? id_obj.raw : id_obj.raw.to_i
          begin
            obj = ::ObjectSpace._id2ref(id)
            obj.is_a?(Frozone::Vm::ObjectObject) ? obj : NilObject::NIL
          rescue RangeError => e
            raise FrozoneException.make(:RangeError, e.message)
          end
        end

        def objectspace_count_objects(_, result_obj)
          counts = ::ObjectSpace.count_objects
          h = {
            SymbolObject.from(:TOTAL) => IntegerObject.new(counts[:TOTAL] || 0),
            SymbolObject.from(:FREE) => IntegerObject.new(counts[:FREE] || 0),
            SymbolObject.from(:T_OBJECT) => IntegerObject.new(counts[:T_OBJECT] || 0),
            SymbolObject.from(:T_CLASS) => IntegerObject.new(counts[:T_CLASS] || 0),
            SymbolObject.from(:T_MODULE) => IntegerObject.new(counts[:T_MODULE] || 0),
            SymbolObject.from(:T_FLOAT) => IntegerObject.new(counts[:T_FLOAT] || 0),
            SymbolObject.from(:T_STRING) => IntegerObject.new(counts[:T_STRING] || 0),
            SymbolObject.from(:T_REGEXP) => IntegerObject.new(counts[:T_REGEXP] || 0),
            SymbolObject.from(:T_ARRAY) => IntegerObject.new(counts[:T_ARRAY] || 0),
            SymbolObject.from(:T_HASH) => IntegerObject.new(counts[:T_HASH] || 0),
            SymbolObject.from(:T_STRUCT) => IntegerObject.new(counts[:T_STRUCT] || 0),
            SymbolObject.from(:T_BIGNUM) => IntegerObject.new(0),
            SymbolObject.from(:T_FILE) => IntegerObject.new(counts[:T_FILE] || 0),
            SymbolObject.from(:T_DATA) => IntegerObject.new(counts[:T_DATA] || 0),
            SymbolObject.from(:T_MATCH) => IntegerObject.new(counts[:T_MATCH] || 0),
            SymbolObject.from(:T_COMPLEX) => IntegerObject.new(counts[:T_COMPLEX] || 0),
            SymbolObject.from(:T_RATIONAL) => IntegerObject.new(counts[:T_RATIONAL] || 0),
            SymbolObject.from(:T_NIL) => IntegerObject.new(0),
            SymbolObject.from(:T_TRUE) => IntegerObject.new(0),
            SymbolObject.from(:T_FALSE) => IntegerObject.new(0),
            SymbolObject.from(:T_SYMBOL) => IntegerObject.new(counts[:T_SYMBOL] || 0),
            SymbolObject.from(:T_FIXNUM) => IntegerObject.new(0),
            SymbolObject.from(:T_UNDEF) => IntegerObject.new(0),
            SymbolObject.from(:T_IMEMO) => IntegerObject.new(0),
            SymbolObject.from(:T_NODE) => IntegerObject.new(0),
            SymbolObject.from(:T_ICLASS) => IntegerObject.new(0),
            SymbolObject.from(:T_ZOMBIE) => IntegerObject.new(0)
          }
          HashObject.new(h.transform_keys { |k| k })
        end

        # Self-hosting helpers: minimal Frozone::Vm::Vm proxy for Frozone-land evaluation

        def kernel_vm_initialize(_, vm_obj, options_obj)
          vm_obj.set_ivar(:@options, options_obj)
          vm_obj
        end

        def kernel_run_vm(_, vm_obj)
          fl_options = vm_obj.get_ivar(:@options)
          opts = fl_options.is_a?(HashObject) ? fl_options.raw : {}

          scripts_obj = opts[SymbolObject.from(:scripts)]
          argv_obj    = opts[SymbolObject.from(:argv)]

          scripts = scripts_obj.is_a?(ArrayObject) ? scripts_obj.raw.map { |s| s.is_a?(StringObject) ? s.raw : s.to_s } : []
          argv    = argv_obj.is_a?(ArrayObject)    ? argv_obj.raw.map    { |a| a.is_a?(StringObject) ? a.raw : a.to_s } : []

          # Set Frozone-land ARGV for the inner script
          script_argv = scripts.empty? ? (argv[1..] || []) : []
          Core::OBJECT_CLASS.set_constant(:ARGV, ArrayObject.new(script_argv.map { |a| StringObject.new(a) }))

          begin
            if scripts.empty?
              file = argv[0]
              file.nil? ? Fiber[:vm_eval].call('', false) : Fiber[:vm_evaluate].call(File.expand_path(file))
            else
              Fiber[:vm_eval].call(scripts.join("\n"), false)
            end
          rescue FrozoneException => e
            vo = e.vm_object
            if vo.is_a?(ObjectObject)
              cls = vo.class_object
              while cls
                break if cls.name == :SystemExit
                cls = cls.superclass
              end
              if cls
                status_obj = vo.get_ivar(:@status)
                exit(status_obj.is_a?(IntegerObject) ? status_obj.raw : 0)
              end
            end
            raise
          end

          NilObject::NIL
        end

        # ENV intrinsics — direct MRI ENV access
        def env_get(_, key)
          val = ENV[key.raw]
          val.nil? ? NilObject::NIL : StringObject.new(val)
        end

        def env_set(_, key, value)
          ENV[key.raw] = value.raw
          value
        end

        def env_delete(_, key)
          val = ENV.delete(key.raw)
          val.nil? ? NilObject::NIL : StringObject.new(val)
        end

        def env_key?(_, key)
          bool_object_for(ENV.key?(key.raw))
        end

        def env_value?(_, value)
          bool_object_for(ENV.value?(value.raw))
        end

        def env_key(_, value)
          k = ENV.key(value.raw)
          k.nil? ? NilObject::NIL : StringObject.new(k)
        end

        def env_keys(_)
          ArrayObject.new(ENV.keys.map { |k| StringObject.new(k) })
        end

        def env_values(_)
          ArrayObject.new(ENV.values.map { |v| StringObject.new(v) })
        end

        def env_size(_)
          IntegerObject.new(ENV.size)
        end

        def env_clear(_)
          ENV.clear
          NilObject::NIL
        end

        def env_pairs(_)
          ArrayObject.new(ENV.map { |k, v| ArrayObject.new([StringObject.new(k), StringObject.new(v)]) })
        end

        def env_to_hash(_)
          HashObject.new(ENV.to_h { |k, v| [StringObject.new(k), StringObject.new(v)] })
        end

      end
    end
  end
end

require_relative 'intrinsics/numeric_intrinsics'
require_relative 'intrinsics/io_intrinsics'
require_relative 'intrinsics/string_intrinsics'
require_relative 'intrinsics/collection_intrinsics'
