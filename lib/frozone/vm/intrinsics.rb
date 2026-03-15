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
          if klass.respond_to?(:instance_variable_get) && klass.instance_variable_get(:@is_singleton_class) &&
             v.respond_to?(:instance_variable_get) && v.instance_variable_get(:@is_singleton_class)
            sc_of_v = v.instance_variable_get(:@singleton_of)
            sc_of_k = klass.instance_variable_get(:@singleton_of)
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
          v.get_ivar(normalize_ivar(name))
        end

        def object_ivar_set(_, v, name, value)
          v.set_ivar(normalize_ivar(name), value)
          value
        end

        def object_ivar_defined(_, v, name)
          bool_object_for(v.ivar_defined?(normalize_ivar(name)))
        end

        def object_ivar_names(_, v)
          names = v.instance_variable_get(:@instance_variables)&.keys || []
          ArrayObject.new(names.map { |k| SymbolObject.from(k) })
        end

        def object_ivar_remove(_, v, name)
          k = normalize_ivar(name)
          ivars = v.instance_variable_get(:@instance_variables)
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
            rescue
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

        # Copy the "ObjectObject" fields into a new instance (for dup/clone).
        # Only works for plain ObjectObject instances (not specialized subclasses like StringObject).
        def copy_object_fields(v, copy, eigenclass: nil, frozen: false)
          copy.instance_variable_set(:@class_object, v.class_object)
          copy.instance_variable_set(:@instance_variables, v.instance_variable_get(:@instance_variables).dup)
          copy.instance_variable_set(:@eigenclass, eigenclass)
          copy.instance_variable_set(:@frozen_object, frozen)
          copy
        end

        def object_dup(_, v)
          # Only works for plain ObjectObject instances — specialized types (String, Array, etc.)
          # define their own dup methods in core Ruby.
          return v unless v.class == ObjectObject
          copy = ObjectObject.allocate
          copy_object_fields(v, copy, eigenclass: nil, frozen: false)
        end

        def object_clone(_, v, freeze_opt = NilObject::NIL)
          # Only works for plain ObjectObject instances — specialized types define their own clone.
          return v unless v.class == ObjectObject
          copy = ObjectObject.allocate
          # Copy singleton class if it exists (clone copies singleton, dup does not)
          sc_copy = nil
          if v.eigenclass
            sc_copy = ClassObject.new(nil, nil, v.eigenclass.superclass)
            sc_copy.instance_variable_set(:@is_singleton_class, true)
            sc_copy.instance_variable_set(:@singleton_of, copy)
            orig_methods = v.eigenclass.instance_variable_get(:@methods) || {}
            sc_copy.instance_variable_set(:@methods, orig_methods.dup)
            orig_constants = v.eigenclass.instance_variable_get(:@constants) || {}
            sc_copy.instance_variable_set(:@constants, orig_constants.dup)
          end
          # Handle freeze: option (freeze: false means unfreeze clone)
          freeze_val = freeze_opt.is_a?(NilObject) ? nil : freeze_opt.truthy?
          frozen = if freeze_val == false then false
                   elsif freeze_val.nil? then v.frozen_object?
                   else true
                   end
          copy_object_fields(v, copy, eigenclass: sc_copy, frozen: frozen)
        end

        def string_initialize(context, receiver, str_arg, _encoding = NilObject::NIL)
          # Convert str_arg to string if needed
          str_val = str_arg.is_a?(StringObject) ? str_arg.raw : str_arg.dispatch(context, :to_s, [], {}).raw
          receiver.raw = str_val.dup
          NilObject::NIL
        end

        def string_clone(_, v, freeze_opt = NilObject::NIL)
          copy = StringObject.new(v.raw.dup)
          if v.eigenclass
            sc_copy = ClassObject.new(nil, nil, v.eigenclass.superclass)
            sc_copy.instance_variable_set(:@is_singleton_class, true)
            sc_copy.instance_variable_set(:@singleton_of, copy)
            orig_methods = v.eigenclass.instance_variable_get(:@methods) || {}
            sc_copy.instance_variable_set(:@methods, orig_methods.dup)
            copy.instance_variable_set(:@eigenclass, sc_copy)
          end
          freeze_val = freeze_opt.is_a?(NilObject) ? nil : freeze_opt.truthy?
          frozen = if freeze_val == false then false
                   elsif freeze_val.nil? then v.frozen_object?
                   else true
                   end
          copy.instance_variable_set(:@frozen_object, frozen)
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
            mod.instance_variable_get(:@methods).each do |name, meth|
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
          exc_obj.set_ivar(:@backtrace, bt) unless exc_obj.is_a?(NilObject)
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

        def kernel_raise(context, _receiver, msg = NilObject::NIL, message_arg = nil, _backtrace = nil)
          current_exc = GLOBALS[:"$!"]
          cause = (current_exc && !current_exc.is_a?(NilObject)) ? current_exc : nil

          if msg.is_a?(NilObject)
            # bare `raise` re-raises current exception or raises RuntimeError
            if cause
              raise FrozoneException.new(cause, cause.get_ivar(:@message)&.raw || "RuntimeError")
            end
            raise FrozoneException.make(:RuntimeError, "RuntimeError")
          elsif msg.is_a?(ClassObject) || msg.is_a?(ModuleObject)
            # raise SomeClass, "message"
            msg_str = message_arg ? message_arg.dispatch(context, :to_s, [], {}).raw : msg.name.to_s
            exc_obj = ObjectObject.new(msg)
            exc_obj.set_ivar(:@message, StringObject.new(msg_str))
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
            msg.set_ivar(:@cause, cause) if cause && msg.respond_to?(:set_ivar)
            set_exc_backtrace(msg, context)
            raise FrozoneException.new(msg, msg_str)
          end
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
            raise FrozoneException.make(:UncaughtThrowError, e.message)
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
          class_name = receiver.class_object.name
          exc = if Fiber[:mm_implicit_self]
                  FrozoneException.make(:NameError, "undefined local variable or method '#{name_sym}' for an instance of #{class_name}", name: name_sym, receiver: receiver)
                else
                  FrozoneException.make(:NoMethodError, "undefined method '#{name_sym}' for an instance of #{class_name}", name: name_sym, receiver: receiver)
                end
          set_exc_backtrace(exc.vm_object, context)
          raise exc
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
                     raw.is_a?(Method) ? raw.bound_copy(name, receiver) : DefinedMethod.new(name, raw.instance_variable_get(:@block_obj), receiver)
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
            c.instance_variable_get(:@constants)&.each_key { |k| names << SymbolObject.from(k) }
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
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          val = receiver.get_class_var(name)
          raise FrozoneException.make(:NameError, "uninitialized class variable #{name} in #{receiver.name}") if val.nil?
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
            receiver.instance_variable_get(:@private_constants)&.delete(name)
          end
          receiver
        end

        def module_remove_const(_, receiver, name_obj)
          name = name_obj.is_a?(SymbolObject) ? name_obj.raw : name_obj.raw.to_sym
          val = receiver.get_constant(name)
          raise FrozoneException.make(:NameError, "constant #{name} not defined") if val.nil?
          receiver.instance_variable_get(:@constants).delete(name)
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
            mod.instance_variable_get(:@methods).each do |name, m|
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
            mod.instance_variable_get(:@methods).each do |name, m|
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
          UnboundMethodObject.new(m, name, receiver)
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

        def bound_method_parameters(_, receiver)
          return ArrayObject.new([]) unless receiver.is_a?(BoundMethodObject)
          m = receiver.raw_method
          return ArrayObject.new([]) unless m.is_a?(Method)
          params = []
          m.required_params.each { |p| params << ArrayObject.new([SymbolObject.from(:req), SymbolObject.from(p)]) }
          m.optional_params.each { |p, _| params << ArrayObject.new([SymbolObject.from(:opt), SymbolObject.from(p)]) }
          params << ArrayObject.new([SymbolObject.from(:rest), SymbolObject.from(m.rest_param)]) if m.rest_param && m.rest_param != :__no_rest__
          m.post_params.each { |p| params << ArrayObject.new([SymbolObject.from(:req), SymbolObject.from(p)]) }
          m.required_kw_params.each { |p| params << ArrayObject.new([SymbolObject.from(:keyreq), SymbolObject.from(p)]) }
          m.optional_kw_params.each { |p, _| params << ArrayObject.new([SymbolObject.from(:key), SymbolObject.from(p)]) }
          params << ArrayObject.new([SymbolObject.from(:keyrest), SymbolObject.from(m.kw_rest_param)]) if m.kw_rest_param && m.kw_rest_param != :__no_kwargs__
          params << ArrayObject.new([SymbolObject.from(:block), SymbolObject.from(m.block_param)]) if m.block_param
          ArrayObject.new(params)
        end

        def bound_method_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(BoundMethodObject)
          SymbolObject.from(receiver.bound_name)
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
          h = receiver.bound_receiver.object_id ^ receiver.bound_name.hash
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
          m = receiver.is_a?(UnboundMethodObject) ? receiver.raw_method : nil
          return ArrayObject.new([]) unless m
          params = []
          m.required_params.each { |p| params << ArrayObject.new([SymbolObject.from(:req), SymbolObject.from(p)]) }
          m.optional_params.each { |p, _| params << ArrayObject.new([SymbolObject.from(:opt), SymbolObject.from(p)]) }
          params << ArrayObject.new([SymbolObject.from(:rest), SymbolObject.from(m.rest_param)]) if m.rest_param
          m.post_params.each { |p| params << ArrayObject.new([SymbolObject.from(:req), SymbolObject.from(p)]) }
          m.required_kw_params.each { |p| params << ArrayObject.new([SymbolObject.from(:keyreq), SymbolObject.from(p)]) }
          m.optional_kw_params.each { |p, _| params << ArrayObject.new([SymbolObject.from(:key), SymbolObject.from(p)]) }
          params << ArrayObject.new([SymbolObject.from(:keyrest), SymbolObject.from(m.kw_rest_param)]) if m.kw_rest_param
          params << ArrayObject.new([SymbolObject.from(:block), SymbolObject.from(m.block_param)]) if m.block_param
          ArrayObject.new(params)
        end

        def unbound_method_name(_, receiver)
          return NilObject::NIL unless receiver.is_a?(UnboundMethodObject)
          SymbolObject.from(receiver.unbound_name)
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
          raise FrozoneException.make(:LoadError, "cannot load such file -- #{path}") if full_path.nil?
          return FalseObject::FALSE if loaded_paths.include?(full_path)
          loaded.push(StringObject.new(full_path))
          begin
            Fiber[:vm_evaluate].call(full_path)
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
          Fiber[:vm_evaluate].call(full_path)
          TrueObject::TRUE
        end

        def kernel_load(_, _receiver, path_obj)
          path = path_obj.raw
          full_path = File.exist?(path) ? path : resolve_load_path(path)
          raise FrozoneException.make(:LoadError, "cannot load such file -- #{path}") if full_path.nil?
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
            has_rest = !blk_obj.instance_variable_get(:@rest_param).nil?
            opt_count = blk_obj.instance_variable_get(:@optional_params)&.length || 0
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
          copy.instance_variable_set(:@class_object, proc_obj.class_object)
          copy_object_fields(proc_obj, copy, eigenclass: nil, frozen: false)
          copy
        end

        def proc_clone(context, proc_obj, freeze_opt = NilObject::NIL)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.block_object : proc_obj
          copy = ProcObject.new(blk, lambda: proc_obj.lambda?)
          copy.instance_variable_set(:@class_object, proc_obj.class_object)
          freeze_val = freeze_opt.is_a?(NilObject) ? nil : freeze_opt.truthy?
          frozen = if freeze_val == false then false
                   elsif freeze_val.nil? then proc_obj.frozen_object?
                   else true
                   end
          sc_copy = nil
          if proc_obj.eigenclass
            sc_copy = ClassObject.new(nil, nil, proc_obj.eigenclass.superclass)
            sc_copy.instance_variable_set(:@is_singleton_class, true)
            sc_copy.instance_variable_set(:@singleton_of, copy)
            orig_methods = proc_obj.eigenclass.instance_variable_get(:@methods) || {}
            sc_copy.instance_variable_set(:@methods, orig_methods.dup)
          end
          copy_object_fields(proc_obj, copy, eigenclass: sc_copy, frozen: frozen)
          copy
        end

        def proc_arity(_, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.instance_variable_get(:@block_object) : proc_obj
          if blk.is_a?(NativeBlock) && blk.parameters_override
            params = blk.parameters_override
            req = params.count { |p| p[0] == :req || p[0] == :keyreq }
            has_rest = params.any? { |p| p[0] == :rest || p[0] == :keyrest }
            return has_rest ? IntegerObject.new(-(req + 1)) : IntegerObject.new(req)
          end
          return IntegerObject.new(0) unless blk.is_a?(BlockObject)
          is_lambda = blk.instance_variable_get(:@is_lambda)
          req = blk.instance_variable_get(:@required_params)&.length || 0
          opt = blk.instance_variable_get(:@optional_params)&.length || 0
          rest = blk.instance_variable_get(:@rest_param)
          post = blk.instance_variable_get(:@post_params)&.length || 0
          req_kw = blk.instance_variable_get(:@required_kw_params)&.length || 0
          opt_kw = blk.instance_variable_get(:@optional_kw_params)&.length || 0
          kw_rest = blk.instance_variable_get(:@kw_rest_param)
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
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.instance_variable_get(:@block_object) : proc_obj
          if blk.is_a?(NativeBlock) && blk.parameters_override
            return ArrayObject.new(blk.parameters_override.map { |p| ArrayObject.new(p.map { |s| SymbolObject.from(s) }) })
          end
          return ArrayObject.new([]) unless blk.is_a?(BlockObject)
          # `it` implicit parameter: return [[:req]] for lambda, [[:opt]] for proc (Ruby 4.0+)
          if blk.instance_variable_get(:@it_param)
            is_lambda = blk.instance_variable_get(:@is_lambda)
            return ArrayObject.new([ArrayObject.new([SymbolObject.from(is_lambda ? :req : :opt)])])
          end
          params = []
          is_lambda = blk.instance_variable_get(:@is_lambda)
          req_type = is_lambda ? :req : :opt
          req_params = blk.instance_variable_get(:@required_params) || []
          opt_params = blk.instance_variable_get(:@optional_params) || []
          rest_param = blk.instance_variable_get(:@rest_param)
          post_params = blk.instance_variable_get(:@post_params) || []
          req_kw = blk.instance_variable_get(:@required_kw_params) || []
          opt_kw = blk.instance_variable_get(:@optional_kw_params) || []
          kw_rest = blk.instance_variable_get(:@kw_rest_param)
          blk_param = blk.instance_variable_get(:@block_param)
          req_params.each { |n| params << ArrayObject.new([SymbolObject.from(req_type), SymbolObject.from(n.is_a?(Hash) ? :* : n)]) }
          opt_params.each { |n, _| params << ArrayObject.new([SymbolObject.from(:opt), SymbolObject.from(n)]) }
          params << ArrayObject.new([SymbolObject.from(:rest), rest_param ? SymbolObject.from(rest_param) : SymbolObject.from(:*)]) if rest_param || blk.instance_variable_get(:@rest_param) == :__implicit_rest__
          post_params.each { |n| params << ArrayObject.new([SymbolObject.from(req_type), SymbolObject.from(n)]) }
          req_kw.each { |n| params << ArrayObject.new([SymbolObject.from(:keyreq), SymbolObject.from(n)]) }
          opt_kw.each { |n, _| params << ArrayObject.new([SymbolObject.from(:key), SymbolObject.from(n)]) }
          params << ArrayObject.new([SymbolObject.from(:keyrest), kw_rest == :__no_kwargs__ ? SymbolObject.from(:nil) : SymbolObject.from(kw_rest)]) if kw_rest
          params << ArrayObject.new([SymbolObject.from(:block), SymbolObject.from(blk_param)]) if blk_param
          ArrayObject.new(params)
        end

        def proc_source_location(_, proc_obj)
          blk = proc_obj.is_a?(ProcObject) ? proc_obj.instance_variable_get(:@block_object) : proc_obj
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

        def kernel_eval(context, _receiver, code_obj, binding_arg = NilObject::NIL)
          return NilObject::NIL unless code_obj.is_a?(StringObject)
          code = code_obj.raw
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
          eval_filepath = context.call_site ? "(eval at #{context.call_site})" : "(eval)"
          parser = Parser.new(code, outer_locals: binding_frame.local_names, encoding: code_enc, filepath: eval_filepath)
          ast = parser.ast(raise_syntax_errors: true)
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
          raise FrozoneException.make(:TypeError, "can't create instance of singleton class") if klass.instance_variable_get(:@is_singleton_class)
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

        def class_allocate(context, klass)
          raise FrozoneException.make(:TypeError, "can't create instance of singleton class") if klass.instance_variable_get(:@is_singleton_class)
          raise FrozoneException.make(:TypeError, "can't create instance of virtual class") if klass.equal?(Core::CLASS_CLASS) || klass.equal?(Core::MODULE_CLASS)
          ObjectObject.new(klass)
        end

        def class_superclass(_, klass)
          sc = klass.is_a?(ClassObject) ? klass.superclass : nil
          sc.nil? ? NilObject::NIL : sc
        end

        # Integer
        def integer_spaceship(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(IntegerObject) || v2.is_a?(FloatObject)
          result = v1.raw <=> v2.raw
          result.nil? ? NilObject::NIL : IntegerObject.new(result)
        end

        def integer_hash(_, v) = IntegerObject.new(v.raw.hash)

        def integer_eql(_, v1, v2) = bool_object_for(v2.is_a?(IntegerObject) && v1.raw == v2.raw)

        def integer_to_s(_, v, base = nil)
          base.nil? || base.is_a?(NilObject) ? StringObject.new(v.raw.to_s) : StringObject.new(v.raw.to_s(base.raw))
        end

        def integer_abs(_, v) = IntegerObject.new(v.raw.abs)
        def integer_chr(_, v, enc = nil) = StringObject.new(v.raw.chr)
        def integer_bitand(_, v1, v2) = IntegerObject.new(v1.raw & v2.raw)
        def integer_bitor(_, v1, v2)  = IntegerObject.new(v1.raw | v2.raw)
        def integer_bitxor(_, v1, v2) = IntegerObject.new(v1.raw ^ v2.raw)
        def integer_bitnot(_, v)      = IntegerObject.new(~v.raw)
        SHIFT_LIMIT = 2**32

        def integer_lshift(_, v1, v2)
          n = v1.raw
          m = v2.is_a?(IntegerObject) ? v2.raw : v2.raw.to_i
          if m < 0
            shift = m.abs > 1_000_000 ? 1_000_000 : m.abs
            IntegerObject.new(n >> shift)
          elsif m >= SHIFT_LIMIT && n != 0
            raise FrozoneException.make(:RangeError, 'shift width too big')
          else
            IntegerObject.new(n << m)
          end
        end

        def integer_rshift(_, v1, v2)
          n = v1.raw
          m = v2.is_a?(IntegerObject) ? v2.raw : v2.raw.to_i
          if m < 0
            raise FrozoneException.make(:RangeError, 'shift width too big') if m.abs >= SHIFT_LIMIT && n != 0
            IntegerObject.new(n << m.abs)
          elsif m > 1_000_000
            IntegerObject.new(n >= 0 ? 0 : -1)
          else
            IntegerObject.new(n >> m)
          end
        end
        def integer_bit(_, v, n)      = IntegerObject.new(v.raw[n.raw])
        def integer_bit_length(_, v)  = IntegerObject.new(v.raw.bit_length)

        def integer_raw(v)
          return v.raw if v.is_a?(IntegerObject) || v.is_a?(FloatObject)
          raise FrozoneException.make(:TypeError, "#{v.is_a?(ObjectObject) ? (v.class_object&.name || 'Object') : v.class} can't be coerced into Integer")
        end

        def numeric_wrap(result)
          case result
          when ::Float    then FloatObject.new(result)
          when ::Integer  then IntegerObject.new(result)
          when ::Rational then Core::OBJECT_CLASS.get_constant(:Rational) ? make_rational(result) : FloatObject.new(result.to_f)
          else IntegerObject.new(result.to_i)
          end
        end

        def make_rational(r)
          rat_class = Core::OBJECT_CLASS.get_constant(:Rational)
          obj = ObjectObject.new(rat_class)
          obj.set_ivar(:@numerator, IntegerObject.new(r.numerator))
          obj.set_ivar(:@denominator, IntegerObject.new(r.denominator))
          obj
        end

        def integer__lt_(_, v1, v2)  = bool_object_for(v1.raw <  integer_raw(v2))
        def integer__le_(_, v1, v2)  = bool_object_for(v1.raw <= integer_raw(v2))
        def integer__ge_(_, v1, v2)  = bool_object_for(v1.raw >= integer_raw(v2))
        def integer__gt_(_, v1, v2)  = bool_object_for(v1.raw >  integer_raw(v2))
        def integer__eq_(_, v1, v2)  = bool_object_for(v1.raw == (v2.is_a?(IntegerObject) || v2.is_a?(FloatObject) ? v2.raw : nil))

        def integer__plus_(_, v1, v2)  = numeric_wrap(v1.raw + integer_raw(v2))
        def integer__minus_(_, v1, v2) = numeric_wrap(v1.raw - integer_raw(v2))
        def integer__mul_(_, v1, v2)   = numeric_wrap(v1.raw * integer_raw(v2))
        def integer__div_(_, v1, v2)   = numeric_wrap(v1.raw / integer_raw(v2))
        def integer__mod_(_, v1, v2)   = numeric_wrap(v1.raw % integer_raw(v2))
        def integer__pow_(_, v1, v2)   = numeric_wrap(v1.raw ** integer_raw(v2))

        def integer_to_f(_, v) = FloatObject.new(v.raw.to_f)

        def integer_to_r(context, v)
          r_class = Core::OBJECT_CLASS.get_constant(:Rational)
          return StringObject.new("#{v.raw}/1") unless r_class
          r_class.dispatch(context, :new, [v, IntegerObject.new(1)], {})
        end

        def integer_to_c(context, v)
          c_class = Core::OBJECT_CLASS.get_constant(:Complex)
          return StringObject.new("#{v.raw}+0i") unless c_class
          c_class.dispatch(context, :new, [v, IntegerObject.new(0)], {})
        end

        # Float intrinsics
        def float_eq(_, v1, v2)
          return bool_object_for(false) unless v2.is_a?(FloatObject) || v2.is_a?(IntegerObject)
          bool_object_for(v1.raw == v2.raw)
        end

        def float_eql(_, v1, v2)       = bool_object_for(v2.is_a?(FloatObject) && v1.raw == v2.raw)
        def float_hash(_, v)           = IntegerObject.new(v.raw.hash)

        def float_spaceship(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(FloatObject) || v2.is_a?(IntegerObject)
          r = v1.raw <=> v2.raw
          r ? IntegerObject.new(r) : NilObject::NIL
        end

        def float_to_s(_, v)           = StringObject.new(v.raw.inspect)
        def float_to_i(_, v)           = IntegerObject.new(v.raw.to_i)
        def float_to_f(_, v)           = v
        def float_to_r(_, v)           = make_rational(v.raw.to_r)
        def float_abs(_, v)            = FloatObject.new(v.raw.abs)

        def float_ceil(_, v, n = nil)
          n_raw = n.nil? || n.is_a?(NilObject) ? nil : n.raw
          result = n_raw.nil? ? v.raw.ceil : v.raw.ceil(n_raw)
          result.is_a?(::Integer) ? IntegerObject.new(result) : FloatObject.new(result)
        end

        def float_floor(_, v, n = nil)
          n_raw = n.nil? || n.is_a?(NilObject) ? nil : n.raw
          result = n_raw.nil? ? v.raw.floor : v.raw.floor(n_raw)
          result.is_a?(::Integer) ? IntegerObject.new(result) : FloatObject.new(result)
        end

        def float_round(_, v, n = nil, half = nil)
          n_raw = n.nil? || n.is_a?(NilObject) ? nil : n.raw
          half_raw = half.nil? || half.is_a?(NilObject) ? nil : (half.is_a?(SymbolObject) ? half.raw : half.raw.to_sym)
          opts = half_raw ? { half: half_raw } : {}
          result = n_raw.nil? ? v.raw.round(**opts) : v.raw.round(n_raw, **opts)
          result.is_a?(::Integer) ? IntegerObject.new(result) : FloatObject.new(result)
        end

        def float_truncate(_, v, n = nil)
          n_raw = n.nil? || n.is_a?(NilObject) ? nil : n.raw
          result = n_raw.nil? ? v.raw.truncate : v.raw.truncate(n_raw)
          result.is_a?(::Integer) ? IntegerObject.new(result) : FloatObject.new(result)
        end
        def float_infinity(_)    = FloatObject.new(::Float::INFINITY)
        def float_nan(_)         = FloatObject.new(::Float::NAN)
        def float_next_float(_, v) = FloatObject.new(v.raw.next_float)
        def float_prev_float(_, v) = FloatObject.new(v.raw.prev_float)
        def float_rationalize(context, v, eps = nil)
          if eps.nil? || eps.is_a?(NilObject)
            make_rational(v.raw.rationalize)
          elsif eps.is_a?(FloatObject) || eps.is_a?(IntegerObject)
            eps_raw = eps.raw < 0 ? -eps.raw : eps.raw
            make_rational(v.raw.rationalize(eps_raw))
          else
            num = eps.get_ivar(:@numerator)
            den = eps.get_ivar(:@denominator)
            eps_r = Rational(num.raw, den.raw)
            eps_r = -eps_r if eps_r < 0
            make_rational(v.raw.rationalize(eps_r))
          end
        end
        def float_nan?(_, v)           = bool_object_for(v.raw.nan?)

        def float_infinite?(_, v)
          r = v.raw.infinite?
          r ? IntegerObject.new(r) : NilObject::NIL
        end

        def float_finite?(_, v)        = bool_object_for(v.raw.finite?)
        def float_zero?(_, v)          = bool_object_for(v.raw.zero?)
        def float_positive?(_, v)      = bool_object_for(v.raw.positive?)
        def float_negative?(_, v)      = bool_object_for(v.raw.negative?)

        def float_divmod(_, v1, v2)
          q, r = v1.raw.divmod(v2.raw)
          ArrayObject.new([IntegerObject.new(q), FloatObject.new(r)])
        end

        def float__lt_(_, v1, v2) = v2.is_a?(FloatObject) || v2.is_a?(IntegerObject) ? bool_object_for(v1.raw <  v2.raw) : FalseObject::FALSE
        def float__le_(_, v1, v2) = v2.is_a?(FloatObject) || v2.is_a?(IntegerObject) ? bool_object_for(v1.raw <= v2.raw) : FalseObject::FALSE
        def float__ge_(_, v1, v2) = v2.is_a?(FloatObject) || v2.is_a?(IntegerObject) ? bool_object_for(v1.raw >= v2.raw) : FalseObject::FALSE
        def float__gt_(_, v1, v2) = v2.is_a?(FloatObject) || v2.is_a?(IntegerObject) ? bool_object_for(v1.raw >  v2.raw) : FalseObject::FALSE

        def float__plus_(_, v1, v2)  = FloatObject.new(v1.raw + v2.raw)
        def float__minus_(_, v1, v2) = FloatObject.new(v1.raw - v2.raw)
        def float__mul_(_, v1, v2)   = FloatObject.new(v1.raw * v2.raw)
        def float__div_(_, v1, v2)   = FloatObject.new(v1.raw / v2.raw)
        def float__mod_(_, v1, v2)   = FloatObject.new(v1.raw % v2.raw)
        def float__pow_(_, v1, v2)   = FloatObject.new(v1.raw ** v2.raw)

        # Math module functions
        def float_sqrt(_, v)  = FloatObject.new(::Math.sqrt(v.raw))
        def float_cbrt(_, v)  = FloatObject.new(::Math.cbrt(v.raw))
        def float_exp(_, v)   = FloatObject.new(::Math.exp(v.raw))
        def float_log(_, v)   = FloatObject.new(::Math.log(v.raw))
        def float_log2(_, v)  = FloatObject.new(::Math.log2(v.raw))
        def float_log10(_, v) = FloatObject.new(::Math.log10(v.raw))
        def float_sin(_, v)   = FloatObject.new(::Math.sin(v.raw))
        def float_cos(_, v)   = FloatObject.new(::Math.cos(v.raw))
        def float_tan(_, v)   = FloatObject.new(::Math.tan(v.raw))
        def float_asin(_, v)  = FloatObject.new(::Math.asin(v.raw))
        def float_acos(_, v)  = FloatObject.new(::Math.acos(v.raw))
        def float_atan(_, v)  = FloatObject.new(::Math.atan(v.raw))
        def float_atan2(_, y, x) = FloatObject.new(::Math.atan2(y.raw, x.raw))
        def float_sinh(_, v)  = FloatObject.new(::Math.sinh(v.raw))
        def float_cosh(_, v)  = FloatObject.new(::Math.cosh(v.raw))
        def float_tanh(_, v)  = FloatObject.new(::Math.tanh(v.raw))
        def float_asinh(_, v) = FloatObject.new(::Math.asinh(v.raw))
        def float_acosh(_, v) = FloatObject.new(::Math.acosh(v.raw))
        def float_atanh(_, v) = FloatObject.new(::Math.atanh(v.raw))
        def float_hypot(_, a, b) = FloatObject.new(::Math.hypot(a.raw, b.raw))
        def float_frexp(_, v)
          m, e = ::Math.frexp(v.raw)
          ArrayObject.new([FloatObject.new(m), IntegerObject.new(e)])
        end
        def float_ldexp(_, v, n) = FloatObject.new(::Math.ldexp(v.raw, n.raw))

        # File / Dir
        def file_join(_, parts)
          strs = parts.raw.flat_map { |p| p.is_a?(ArrayObject) ? p.raw.map(&:raw) : p.raw }
          StringObject.new(File.join(*strs))
        end

        def file_dirname(_, path) = StringObject.new(File.dirname(path.raw))

        def file_basename(_, path, suffix = nil)
          result = suffix.nil? || suffix.is_a?(NilObject) ? File.basename(path.raw) : File.basename(path.raw, suffix.raw)
          StringObject.new(result)
        end

        def file_expand_path(_, path, base = nil)
          result = base.nil? || base.is_a?(NilObject) ? File.expand_path(path.raw) : File.expand_path(path.raw, base.raw)
          StringObject.new(result)
        end

        def file_exist(_, path) = bool_object_for(File.exist?(path.raw))
        def file_directory(_, path) = bool_object_for(File.directory?(path.raw))
        def file_file(_, path) = bool_object_for(File.file?(path.raw))
        def file_readable(_, path) = bool_object_for(File.readable?(path.raw))
        def file_executable(_, path) = bool_object_for(File.executable?(path.raw))
        def file_writable(_, path) = bool_object_for(File.writable?(path.raw))

        def file_size(_, path)
          s = File.size?(path.raw)
          s ? IntegerObject.new(s) : NilObject::NIL
        end

        def file_read(_, path) = StringObject.new(File.read(path.raw))

        def file_write(_, path, content)
          File.write(path.raw, content.raw)
          IntegerObject.new(content.raw.length)
        end

        def file_open(context, path, mode, block)
          mode_str = mode.is_a?(NilObject) || mode.nil? ? 'r' : mode.raw
          if block && !block.is_a?(NilObject)
            File.open(path.raw, mode_str) do |f|
              io_obj = IOObject.new(f, Core.io_class)
              block.invoke(context, [io_obj])
            end
            NilObject::NIL
          else
            IOObject.new(File.open(path.raw, mode_str), Core.io_class)
          end
        end

        def file_delete(_, paths)
          paths.raw.each { |p| File.delete(p.raw) rescue nil }
          IntegerObject.new(paths.raw.length)
        end

        def file_rename(_, from, to) = (File.rename(from.raw, to.raw); IntegerObject.new(0))
        def file_symlink(_, path) = bool_object_for(File.symlink?(path.raw))
        def file_symlink_create(_, target, link) = (File.symlink(target.raw, link.raw); IntegerObject.new(0))
        def file_zero(_, path) = bool_object_for(File.zero?(path.raw))

        def file_fnmatch(_, pattern, path, flags)
          bool_object_for(File.fnmatch(pattern.raw, path.raw, flags.raw))
        end

        def file_stat(_, path)
          st = File.stat(path.raw)
          obj = ObjectObject.new(Core::OBJECT_CLASS)
          obj.instance_variable_set(:@__stat__, st)
          obj
        end

        def file_split(_, path)
          parts = File.split(path.raw)
          ArrayObject.new(parts.map { |p| StringObject.new(p) })
        end

        def dir_pwd(_) = StringObject.new(Dir.pwd)
        def dir_home(_) = StringObject.new(Dir.home)

        def dir_glob(_, pattern)
          ArrayObject.new(Dir.glob(pattern.raw).map { |p| StringObject.new(p) })
        end

        def dir_chdir(context, path, block)
          path_raw = path.is_a?(NilObject) || path.nil? ? nil : path.raw
          if block && !block.is_a?(NilObject)
            result = path_raw ? Dir.chdir(path_raw) { block.invoke(context, [StringObject.new(Dir.pwd)]) } :
                                Dir.chdir { block.invoke(context, [StringObject.new(Dir.pwd)]) }
            result.is_a?(ObjectObject) ? result : NilObject::NIL
          else
            Dir.chdir(path_raw || Dir.pwd)
            NilObject::NIL
          end
        end

        def dir_mkdir(_, path) = (Dir.mkdir(path.raw); IntegerObject.new(0))

        def dir_entries(_, path)
          entries = Dir.entries(path.raw)
          ArrayObject.new(entries.map { |e| StringObject.new(e) })
        end

        def dir_rmdir(_, path) = (Dir.rmdir(path.raw); IntegerObject.new(0))
        def dir_empty(_, path) = bool_object_for(Dir.empty?(path.raw))
        def dir_exist(_, path) = path.raw && Dir.exist?(path.raw) ? TrueObject::TRUE : FalseObject::FALSE

        def dir_mktmpdir(context, prefix, block)
          require 'tmpdir'
          pfx = prefix.is_a?(NilObject) || prefix.nil? ? nil : prefix.raw
          path = pfx ? Dir.mktmpdir(pfx) : Dir.mktmpdir
          if block && !block.is_a?(NilObject)
            begin
              block.invoke(context, [StringObject.new(path)])
            ensure
              FileUtils.remove_entry(path) rescue nil
            end
          else
            StringObject.new(path)
          end
        end

        def process_pid(_) = IntegerObject.new(Process.pid)
        def process_euid(_) = IntegerObject.new(Process.euid)

        # Time
        def time_now(_) = TimeObject.new(Time.now)

        def time_minus(_, t, other)
          other.is_a?(TimeObject) ? FloatObject.new(t.raw - other.raw) : TimeObject.new(t.raw - other.raw)
        end

        def time_plus(_, t, secs) = TimeObject.new(t.raw + secs.raw)
        def time_to_f(_, t) = FloatObject.new(t.raw.to_f)
        def time_to_i(_, t) = IntegerObject.new(t.raw.to_i)
        def time_to_s(_, t) = StringObject.new(t.raw.to_s)

        # Regexp
        def update_match_globals(m)
          Fiber[:last_match] = m
          if m
            md = MatchDataObject.new(m)
            GLOBALS[:"$~"] = md
            m.captures.each_with_index do |cap, i|
              GLOBALS[:"$#{i + 1}"] = cap ? StringObject.new(cap) : NilObject::NIL
            end
            last_non_nil = m.captures.reverse.find { |c| !c.nil? }
            GLOBALS[:"$+"] = last_non_nil ? StringObject.new(last_non_nil) : NilObject::NIL
            GLOBALS[:"$&"] = StringObject.new(m[0])
            GLOBALS[:"$`"] = StringObject.new(m.pre_match)
            GLOBALS[:"$'"] = StringObject.new(m.post_match)
            md
          else
            GLOBALS[:"$~"] = NilObject::NIL
            GLOBALS.delete_if { |k, _| k.to_s =~ /^\$[1-9]\d*$/ }
            GLOBALS[:"$&"] = GLOBALS[:"$`"] = GLOBALS[:"$'"] = NilObject::NIL
            NilObject::NIL
          end
        end

        def regexp_eq(_, r1, r2)
          return TrueObject::TRUE if r1.equal?(r2)
          return FalseObject::FALSE unless r2.is_a?(RegexpObject)
          bool_object_for(r1.raw == r2.raw)
        end

        def regexp_source(_, r) = StringObject.new(r.raw.source)
        def regexp_options(_, r) = IntegerObject.new(r.raw.options)
        def regexp_inspect(_, r) = StringObject.new(r.raw.inspect)
        def regexp_to_s(_, r) = StringObject.new(r.raw.to_s)
        def regexp_casefold(_, r) = bool_object_for(r.raw.casefold?)
        def regexp_fixed_encoding(_, r) = bool_object_for(r.raw.fixed_encoding?)
        def regexp_escape(_, str) = StringObject.new(Regexp.escape(str.raw.to_s))

        def regexp_union(_, patterns)
          pats = patterns.raw.map { |p| p.is_a?(RegexpObject) ? p.raw : Regexp.escape(p.raw.to_s) }
          RegexpObject.new(pats.join('|'), '')
        end

        def regexp_last_match(_, n = nil)
          md = Fiber[:last_match]
          return NilObject::NIL unless md
          if n.nil? || n.is_a?(NilObject)
            MatchDataObject.new(md)
          else
            cap = md[n.raw]
            cap ? StringObject.new(cap) : NilObject::NIL
          end
        end

        def regexp_match(_, receiver, str)
          s = str.is_a?(StringObject) ? str.raw : str.raw.to_s
          m = receiver.raw.match(s)
          update_match_globals(m)
        end

        def regexp_match_index(_, receiver, str)
          s = str.is_a?(StringObject) ? str.raw : str.raw.to_s
          m = receiver.raw.match(s)
          update_match_globals(m)
          m ? IntegerObject.new(m.begin(0)) : NilObject::NIL
        end

        def match_data_to_a(_, md)
          captures = [md.raw[0]] + md.raw.captures
          ArrayObject.new(captures.map { |c| c ? StringObject.new(c) : NilObject::NIL })
        end

        def match_data_index(_, md, idx)
          raw = md.raw
          val = if idx.is_a?(IntegerObject)
            raw[idx.raw]
          elsif idx.is_a?(StringObject) || idx.is_a?(SymbolObject)
            raw[idx.raw.to_s]
          else
            raw[idx.raw]
          end
          val ? StringObject.new(val) : NilObject::NIL
        end

        def match_data_size(_, md)    = IntegerObject.new(md.raw.size)
        def match_data_pre_match(_, md)  = StringObject.new(md.raw.pre_match)
        def match_data_post_match(_, md) = StringObject.new(md.raw.post_match)
        def match_data_string(_, md)     = StringObject.new(md.raw.string.dup)
        def match_data_regexp(_, md)     = RegexpObject.new(md.raw.regexp.source, md.raw.regexp.options)

        def match_data_begin(_, md, n)
          v = md.raw.begin(n.is_a?(IntegerObject) ? n.raw : n.raw.to_s)
          v ? IntegerObject.new(v) : NilObject::NIL
        end

        def match_data_end(_, md, n)
          v = md.raw.end(n.is_a?(IntegerObject) ? n.raw : n.raw.to_s)
          v ? IntegerObject.new(v) : NilObject::NIL
        end

        def match_data_captures(_, md)
          ArrayObject.new(md.raw.captures.map { |c| c ? StringObject.new(c) : NilObject::NIL })
        end

        def match_data_named_captures(_, md)
          h = md.raw.named_captures.transform_keys { |k| StringObject.new(k) }
                                    .transform_values { |v| v ? StringObject.new(v) : NilObject::NIL }
          HashObject.new(h)
        end

        def match_data_names(_, md)
          ArrayObject.new(md.raw.regexp.named_captures.keys.map { |k| StringObject.new(k) })
        end

        # String
        def string_plus(_, v1, v2)
          raise TypeError, "no implicit conversion of #{v2.class_object&.name || v2.class.name} into String" unless v2.is_a?(StringObject)
          StringObject.new(v1.raw + v2.raw)
        end

        def string_length(_, v) = IntegerObject.new(v.raw.length)
        def string_bytesize(_, v) = IntegerObject.new(v.raw.bytesize)
        def string_to_s(_, v) = v
        def string_to_i(_, v) = IntegerObject.new(v.raw.to_i)
        def string_inspect(_, v) = StringObject.new(v.raw.inspect)

        def string_spaceship(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(StringObject)
          IntegerObject.new(v1.raw <=> v2.raw)
        end

        def string_hash(_, v) = IntegerObject.new(v.raw.hash)

        def string_eql(_, v1, v2) = bool_object_for(v2.is_a?(StringObject) && v1.raw == v2.raw)

        def string_start_with(_, v, *args) = bool_object_for(v.raw.start_with?(*args.map(&:raw)))
        def string_end_with(_, v, *args)   = bool_object_for(v.raw.end_with?(*args.map(&:raw)))
        def string_include(_, v, s)        = bool_object_for(v.raw.include?(s.raw))
        def string_empty(_, v)             = bool_object_for(v.raw.empty?)
        def string_strip(_, v)             = StringObject.new(v.raw.strip)
        def string_lstrip(_, v)            = StringObject.new(v.raw.lstrip)
        def string_rstrip(_, v)            = StringObject.new(v.raw.rstrip)

        def string_chomp(_, v, sep = nil)
          sep.nil? || sep.is_a?(NilObject) ? StringObject.new(v.raw.chomp) : StringObject.new(v.raw.chomp(sep.raw))
        end

        def string_chop(_, v)              = StringObject.new(v.raw.chop)
        def string_upcase(_, v)            = StringObject.new(v.raw.upcase)
        def string_downcase(_, v)          = StringObject.new(v.raw.downcase)
        def string_swapcase(_, v)          = StringObject.new(v.raw.swapcase)
        def string_capitalize(_, v)        = StringObject.new(v.raw.capitalize)
        def string_reverse(_, v)           = StringObject.new(v.raw.reverse)

        def string_reverse_bang(_, v)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v.raw.inspect}") if v.frozen?
          v.raw = v.raw.reverse.freeze
          v
        end

        def string_chars(_, v)             = ArrayObject.new(v.raw.chars.map { |c| StringObject.new(c) })
        def string_bytes(_, v)             = ArrayObject.new(v.raw.bytes.map { |b| IntegerObject.new(b) })
        def string_ord(_, v)               = IntegerObject.new(v.raw.ord)

        def string_split(_, v, sep = nil, limit = nil)
          sep = nil if sep.is_a?(NilObject)
          limit = nil if limit.is_a?(NilObject)
          parts = if sep.nil?
            v.raw.split
          elsif limit.nil?
            v.raw.split(sep.is_a?(StringObject) ? sep.raw : sep.raw)
          else
            v.raw.split(sep.is_a?(StringObject) ? sep.raw : sep.raw, limit.raw)
          end
          ArrayObject.new(parts.map { |p| StringObject.new(p) })
        end

        def extract_pattern(context, pattern)
          return pattern.raw if pattern.is_a?(StringObject) || pattern.is_a?(RegexpObject)
          if pattern.is_a?(ObjectObject)
            r = pattern.dispatch(context, :to_str, [], {}) rescue nil
            return r.raw if r.is_a?(StringObject)
          end
          name = pattern.is_a?(ObjectObject) ? (pattern.class_object&.name || 'Object').to_s : pattern.class.name
          raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
        end

        def extract_string_replacement(context, replacement)
          return replacement.raw if replacement.is_a?(StringObject)
          if replacement.is_a?(ObjectObject)
            r = replacement.dispatch(context, :to_str, [], {}) rescue nil
            return r.raw if r.is_a?(StringObject)
          end
          name = replacement.is_a?(ObjectObject) ? (replacement.class_object&.name || 'Object').to_s : replacement.class.name
          raise FrozoneException.make(:TypeError, "no implicit conversion of #{name} into String")
        end

        def block_result_to_s(context, val)
          return val.raw if val.is_a?(StringObject)
          r = val.dispatch(context, :to_s, [], {}) rescue nil
          r.is_a?(StringObject) ? r.raw : val.to_s
        end

        def string_gsub(context, v, pattern, replacement = nil, block = nil)
          pat = extract_pattern(context, pattern)
          has_replacement = !(replacement.nil? || replacement.is_a?(NilObject))
          has_block = block && !block.is_a?(NilObject)
          if has_block && !has_replacement
            result = v.raw.gsub(pat) do |_match|
              update_match_globals($~)
              match_obj = StringObject.new($&)
              block_result_to_s(context, block.invoke(context, [match_obj]))
            end
            StringObject.new(result)
          elsif !has_replacement
            NilObject::NIL
          elsif replacement.is_a?(HashObject)
            result = v.raw.gsub(pat) do |match|
              r = replacement[StringObject.new(match)]
              r.is_a?(NilObject) || r.nil? ? match : block_result_to_s(context, r)
            end
            StringObject.new(result)
          else
            StringObject.new(v.raw.gsub(pat, extract_string_replacement(context, replacement)))
          end
        end

        def string_sub(context, v, pattern, replacement = nil, block = nil)
          pat = extract_pattern(context, pattern)
          has_replacement = !(replacement.nil? || replacement.is_a?(NilObject))
          has_block = block && !block.is_a?(NilObject)
          if has_block && !has_replacement
            result = v.raw.sub(pat) do |_match|
              update_match_globals($~)
              match_obj = StringObject.new($&)
              block_result_to_s(context, block.invoke(context, [match_obj]))
            end
            StringObject.new(result)
          elsif !has_replacement
            NilObject::NIL
          elsif replacement.is_a?(HashObject)
            result = v.raw.sub(pat) do |match|
              r = replacement[StringObject.new(match)]
              r.is_a?(NilObject) || r.nil? ? match : block_result_to_s(context, r)
            end
            StringObject.new(result)
          else
            StringObject.new(v.raw.sub(pat, extract_string_replacement(context, replacement)))
          end
        end

        def string_tr(_, v, from, to) = StringObject.new(v.raw.tr(from.raw, to.raw))

        def string_squeeze(_, v, *args)
          args.empty? ? StringObject.new(v.raw.squeeze) : StringObject.new(v.raw.squeeze(*args.map(&:raw)))
        end

        def string_count(_, v, *args) = IntegerObject.new(v.raw.count(*args.map(&:raw)))
        def string_delete(_, v, *args) = StringObject.new(v.raw.delete(*args.map(&:raw)))

        # Called as string_slice(v, idx) — no length — or string_slice(v, idx, len) — explicit length.
        # String#[] uses :__unset__ sentinel so explicit nil can be distinguished from absent len.
        def string_slice(context, v, idx, len = nil)
          if idx.is_a?(RegexpObject)
            raise FrozoneException.make(:TypeError, "no implicit conversion of nil into Integer") if !len.nil? && len.is_a?(NilObject)
            m = idx.raw.match(v.raw)
            update_match_globals(m)
            unless len.nil?
              cap_idx = begin
                raw = len.raw
                raw.is_a?(Integer) ? raw : Integer(raw)
              rescue NoMethodError, TypeError, ArgumentError
                raise FrozoneException.make(:TypeError, "no implicit conversion of #{len.class_object.name} into Integer")
              end
              cap = m ? m[cap_idx] : nil
              return cap ? StringObject.new(cap) : NilObject::NIL
            end
            return m ? StringObject.new(m[0]) : NilObject::NIL
          end
          # Explicit nil as length raises TypeError; absent len (len.nil? = true) is fine
          raise FrozoneException.make(:TypeError, "no implicit conversion of nil into Integer") if !len.nil? && len.is_a?(NilObject)
          begin
            result = len.nil? ? v.raw[idx.raw] : v.raw[idx.raw, len.raw]
          rescue TypeError => e
            raise FrozoneException.make(:TypeError, e.message)
          rescue NoMethodError
            raise FrozoneException.make(:TypeError, "no implicit conversion into Integer")
          end
          result.nil? ? NilObject::NIL : StringObject.new(result)
        end

        def string_index(_, v, sub, offset = nil)
          result = (offset.nil? || offset.is_a?(NilObject)) ? v.raw.index(sub.raw) : v.raw.index(sub.raw, offset.raw)
          result.nil? ? NilObject::NIL : IntegerObject.new(result)
        end

        def string_rindex(_, v, sub, offset = nil)
          result = (offset.nil? || offset.is_a?(NilObject)) ? v.raw.rindex(sub.raw) : v.raw.rindex(sub.raw, offset.raw)
          result.nil? ? NilObject::NIL : IntegerObject.new(result)
        end

        def string_replace(_, v, other)
          return v if other.is_a?(NilObject)
          v.raw = other.raw.freeze
          v
        end

        def string_succ(_, v)          = StringObject.new(v.raw.succ)

        def string_succ_bang(_, v)
          v.raw = v.raw.succ.freeze
          v
        end

        def string_insert(_, v, index, str)
          v.raw = v.raw.dup.insert(index.raw, str.raw).freeze
          v
        end

        def string_slice_bang(_, v, idx, len = nil)
          mutated = v.raw.dup
          result = len.is_a?(NilObject) || len.nil? ? mutated.slice!(idx.raw) : mutated.slice!(idx.raw, len.raw)
          v.raw = mutated.freeze
          result.nil? ? NilObject::NIL : StringObject.new(result)
        end

        def string_each_line(context, v, sep, block)
          sep_raw = sep.is_a?(NilObject) ? "\n" : sep.raw
          return ArrayObject.new(v.raw.each_line(sep_raw).map { |l| StringObject.new(l) }) if block.nil? || block.is_a?(NilObject)
          v.raw.each_line(sep_raw) { |l| block.invoke(context, [StringObject.new(l)]) }
          v
        end

        def string_b(_, v) = StringObject.new(v.raw.b)
        def string_concat(_, v1, v2)
          raise FrozoneException.make(:FrozenError, "can't modify frozen String: #{v1.raw.inspect}") if v1.frozen?
          v2_str = v2.is_a?(StringObject) ? v2.raw : v2.raw.to_s
          v1.raw << v2_str
          v1
        end
        def string_multiply(_, v, n)
          count = n.is_a?(IntegerObject) ? n.raw : (n.respond_to?(:raw) ? n.raw.to_i : n.to_i)
          raise FrozoneException.make(:ArgumentError, "negative string size (or exceeds maximum allowed string size)") if count < 0
          raise FrozoneException.make(:RangeError, "bignum too big to convert into 'long'") if count > 9_223_372_036_854_775_807
          str = v.raw
          raise FrozoneException.make(:ArgumentError, "argument exceeds the limit") if !str.empty? && count > 1_073_741_823
          StringObject.new(str * count)
        end

        def string_format(_, v, args)
          raw_args = args.is_a?(ArrayObject) ? args.raw.map(&:raw) : args.raw
          StringObject.new(v.raw % raw_args)
        end

        def string_encode(_, v, enc = nil) = v

        def string_force_encoding(context, v, enc)
          enc_name = if enc.is_a?(StringObject)
                       enc.raw
                     elsif enc.respond_to?(:get_ivar)
                       enc.dispatch(context, :name, [], {}).raw rescue enc.get_ivar(:@name)&.raw || enc.to_s
                     else
                       enc.to_s
                     end
          v.raw.force_encoding(enc_name)
          v
        end

        def string_encoding(_, v)
          enc_name = v.raw.encoding.name
          enc_class = Core::OBJECT_CLASS.get_constant(:Encoding)
          return StringObject.new(enc_name) unless enc_class
          const_name = enc_name.tr('-', '_').to_sym
          enc_class.get_constant(const_name) || StringObject.new(enc_name)
        end

        def string_freeze(_, v)           = (v.freeze_object!; v)
        def string_frozen(_, v)           = bool_object_for(v.frozen_object?)
        def string_dup(_, v)              = StringObject.new(v.raw.dup)
        def string_to_sym(_, v)           = SymbolObject.from(v.raw.to_sym)
        def string_to_f(_, v)             = FloatObject.new(v.raw.to_f)
        def string_to_r(_, v)             = NilObject::NIL  # stub

        def string_match(_, v, pattern)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          m = pat.match(v.raw)
          update_match_globals(m)
          m ? MatchDataObject.new(m) : NilObject::NIL
        end

        def string_match_q(_, v, pattern, pos)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          str = v.raw
          result = (pos.is_a?(NilObject) || pos.nil?) ? pat.match?(str) : pat.match?(str, pos.raw)
          bool_object_for(result)
        end

        def string_scan(_, v, pattern)
          pat = pattern.is_a?(StringObject) ? Regexp.new(pattern.raw) : pattern.raw
          results = v.raw.scan(pat)
          ArrayObject.new(results.map { |r| r.is_a?(Array) ? ArrayObject.new(r.map { |s| StringObject.new(s) }) : StringObject.new(r) })
        end

        # Symbol
        def symbol_to_s(_, v) = StringObject.new(v.raw.to_s)
        def symbol_inspect(_, v) = StringObject.new(v.raw.inspect)

        SYMBOL_NAME_CACHE = {}
        def symbol_name(_, v)
          SYMBOL_NAME_CACHE[v.raw] ||= StringObject.new(v.raw.to_s, frozen: true)
        end

        def symbol_hash(_, v) = IntegerObject.new(v.raw.hash)

        def symbol_eql(_, v1, v2) = bool_object_for(v2.is_a?(SymbolObject) && v1.raw == v2.raw)

        def symbol_to_proc(context, sym)
          method_name = sym.raw
          native = NativeBlock.new(
            source_location: nil,
            parameters_override: [[:req], [:rest]],
            is_lambda: true
          ) do |ctx, args, block: nil|
            if args.empty?
              raise FrozoneException.make(:ArgumentError, "no receiver given")
            end
            receiver = args[0]
            rest = args[1..]
            block_obj = block.is_a?(ProcObject) ? block.block_object : block
            block_obj = nil if block_obj.nil? || block_obj.is_a?(NilObject)
            receiver.dispatch(ctx, method_name, rest, {}, block_obj, private_ok: false, public_only: true)
          end
          ProcObject.new(native, lambda: true)
        end

        def symbol_all_symbols(_)
          ArrayObject.new(SymbolObject::SymbolObjects.values)
        end

        # Array
        ARRAY_MAX_SIZE = 1_073_741_823  # 2**30 - 1; prevents allocation hangs for huge sizes

        def array_initialize(context, arr, size_or_array = nil, fill = nil, block = nil)
          size_or_array = nil if size_or_array.nil? || size_or_array.is_a?(NilObject)
          fill = nil if fill.nil? || fill.is_a?(NilObject)
          block = nil if block.nil? || block.is_a?(NilObject)
          arr.raw.clear
          if size_or_array.is_a?(ArrayObject)
            arr.raw.replace(size_or_array.raw.dup)
          elsif size_or_array.is_a?(IntegerObject)
            n = size_or_array.raw
            raise FrozoneException.make(:ArgumentError, "negative array size") if n < 0
            raise FrozoneException.make(:ArgumentError, "array size too big") if n > ARRAY_MAX_SIZE
            if block
              n.times { |i| arr.push(block.invoke(context, [IntegerObject.new(i)])) }
            else
              arr.raw.replace(Array.new(n, fill || NilObject::NIL))
            end
          end
          arr
        end

        def array_new(context, klass, size_or_array = nil, fill = nil, block = nil)
          size_or_array = nil if size_or_array.is_a?(NilObject)
          fill = nil if fill.is_a?(NilObject)
          block = nil if block.is_a?(NilObject)
          # Use the calling class (for Array subclasses); default to ARRAY_CLASS
          cls = klass.is_a?(ClassObject) ? klass : nil
          if size_or_array.is_a?(ArrayObject)
            # Array.new(arr) — copy
            ArrayObject.new(size_or_array.raw.dup, cls)
          elsif size_or_array.is_a?(IntegerObject)
            n = size_or_array.raw
            raise FrozoneException.make(:ArgumentError, "negative array size") if n < 0
            raise FrozoneException.make(:ArgumentError, "array size too big") if n > ARRAY_MAX_SIZE
            if block
              elements = (0...n).map { |i| block.invoke(context, [IntegerObject.new(i)]) }
              ArrayObject.new(elements, cls)
            else
              elements = Array.new(n, fill || NilObject::NIL)
              ArrayObject.new(elements, cls)
            end
          else
            ArrayObject.new([], cls)
          end
        end

        def array_at(_, v, i)
          element = v[i.raw]
          element.nil? ? NilObject::NIL : element
        end


        def array_index_write(_, v, i, val)
          if i.is_a?(IntegerObject)
            v.raw[i.raw] = val
          elsif i.is_a?(RangeObject)
            replacement = val.is_a?(ArrayObject) ? val.raw : [val]
            v.raw[i.raw] = replacement
          else
            raise "Array#[]= index must be an Integer or Range"
          end
          val
        end

        def array_slice_write(_, v, start, length, val)
          raise "Array#[]= start must be an Integer" unless start.is_a?(IntegerObject)
          raise "Array#[]= length must be an Integer" unless length.is_a?(IntegerObject)
          replacement = val.is_a?(ArrayObject) ? val.raw : [val]
          v.raw[start.raw, length.raw] = replacement
          val
        end

        def array_push(_, v, val)
          v.push(val)
          v
        end

        def array_length(_, v) = IntegerObject.new(v.length)

        ARRAY_TO_S_GUARD = :__array_inspect_guard__
        def array_to_s(context, v)
          seen = (Thread.current[ARRAY_TO_S_GUARD] ||= {})
          return StringObject.new("[...]") if seen.key?(v.object_id)
          seen[v.object_id] = true
          begin
            inner = v.raw.map do |e|
              r = e.dispatch(context, :inspect, [], {})
              r = r.dispatch(context, :to_s, [], {}) unless r.is_a?(StringObject)
              r.is_a?(StringObject) ? r.raw : r.to_s
            end.join(", ")
            StringObject.new("[#{inner}]")
          ensure
            seen.delete(v.object_id)
          end
        end

        def array_sort(context, v)
          ArrayObject.new(v.raw.sort { |a, b| a.dispatch(context, :<=>, [b], {}).raw })
        end

        def array_sort_block(context, v, block)
          ArrayObject.new(v.raw.sort { |a, b| block.invoke(context, [a, b]).raw })
        end

        def array_sort_by(context, v, block)
          ArrayObject.new(v.raw.sort_by { |e| block.invoke(context, [e]) })
        end

        def array_reverse(_, v) = ArrayObject.new(v.raw.reverse)

        def array_pop(_, v)
          val = v.raw.pop
          val.nil? ? NilObject::NIL : val
        end

        def array_shift(_, v)
          val = v.raw.shift
          val.nil? ? NilObject::NIL : val
        end

        def array_unshift(_, v, *elems)
          elems.each { |e| v.raw.unshift(e) }
          v
        end

        def array_concat(_, v1, v2)
          elems = v1.equal?(v2) ? v2.raw.dup : v2.raw
          elems.each { |e| v1.raw << e }
          v1
        end

        def array_replace(_, v, other)
          v.raw.replace(other.raw)
          v
        end

        def array_pack(_, v, fmt_obj)
          fmt = fmt_obj.raw.to_s
          ints = v.raw.map { |e| e.is_a?(IntegerObject) ? e.raw : e.raw.to_i }
          StringObject.new(ints.pack(fmt))
        end

        def array_dup(_, v) = ArrayObject.new(v.raw.dup)

        def array_clone(_, v, _freeze_opt = NilObject::NIL) = ArrayObject.new(v.raw.dup)

        def array_sample(_, v) = v.raw.empty? ? NilObject::NIL : v.raw.sample
        def array_shuffle(_, v) = ArrayObject.new(v.raw.shuffle)

        def array_combination(context, v, n, block = nil)
          combos = v.raw.combination(n.raw).map { |c| ArrayObject.new(c) }
          return ArrayObject.new(combos) if block.nil? || block.is_a?(NilObject)
          combos.each { |c| block.invoke(context, [c]) }
          v
        end

        def array_permutation(context, v, n = nil, block = nil)
          n = n.nil? || n.is_a?(NilObject) ? v.raw.length : n.raw
          perms = v.raw.permutation(n).map { |p| ArrayObject.new(p) }
          return ArrayObject.new(perms) if block.nil? || block.is_a?(NilObject)
          perms.each { |p| block.invoke(context, [p]) }
          v
        end

        # Range
        def range_new(_, b, e, excl = nil)
          excl = excl.nil? || excl.is_a?(NilObject) ? false : excl.truthy?
          e = NilObject::NIL if e.nil?
          RangeObject.new(b, e, excl)
        end

        def range_allocate(_, _klass)
          RangeObject.new(NilObject::NIL, NilObject::NIL, false, initialized: false)
        end

        def range_initialized_q(_, range)
          bool_object_for(range.is_a?(RangeObject) && range.initialized?)
        end

        def range_set(_, range, b, e, excl)
          excl = excl.nil? || excl.is_a?(NilObject) ? false : excl.truthy?
          e = NilObject::NIL if e.nil?
          range.set_range(b, e, excl)
          range
        end

        def range_begin(_, range) = range.begin_val
        def range_end(_, range)   = range.end_val
        def range_exclude_end(_, range) = bool_object_for(range.exclusive?)

        # Hash
        def hash_index_write(_, h, key, value)
          h[key] = value
          value
        end

        def hash_size(_, h) = IntegerObject.new(h.size)

        def hash_key(_, h, key) = bool_object_for(h.key?(key))

        def hash_index(context, h, key)
          value = h[key]
          return value unless value.nil?
          if h.default_block
            h.default_block.invoke(context, [h, key])
          elsif h.default_value
            h.default_value
          else
            NilObject::NIL
          end
        end

        def hash_get_default(context, h, key = nil)
          if h.default_block
            key.nil? || key.is_a?(NilObject) ? NilObject::NIL : h.default_block.invoke(context, [h, key])
          elsif h.default_value
            h.default_value
          else
            NilObject::NIL
          end
        end

        def hash_set_default(_, h, val)
          h.default_block = nil
          h.default_value = val.is_a?(NilObject) ? nil : val
          val
        end


        def hash_get_default_proc(_, h)
          h.default_block || NilObject::NIL
        end

        def hash_set_default_proc(_, h, prc)
          if prc.is_a?(NilObject)
            h.default_block = nil
          elsif prc.is_a?(ProcObject)
            h.default_block = prc
            h.default_value = nil
          else
            raise FrozoneException.make(:TypeError, "wrong argument type #{prc.class.name} (expected Proc/nil)")
          end
          prc
        end

        def hash_new(_, default = nil, block = nil)
          proc_obj = if block.is_a?(ProcObject)
            block
          elsif block.is_a?(BlockObject)
            ProcObject.new(block)
          elsif block && !block.is_a?(NilObject)
            ProcObject.new(block)
          end
          if proc_obj
            HashObject.new({}, default_block: proc_obj)
          elsif default && !default.is_a?(NilObject)
            HashObject.new({}, default_value: default)
          else
            HashObject.new({})
          end
        end

        def hash_each(context, h, block)
          h.raw.each { |k, v| block.invoke(context, [ArrayObject.new([k, v])]) }
          h
        end

        def hash_delete(_, h, key)
          val = h[key]
          h.delete(key)
          val.nil? ? NilObject::NIL : val
        end

        def hash_clear(_, h)
          h.clear_elements if h.is_a?(HashObject)
          h
        end

        def hash_transform_keys_bang(context, h, hash_arg, block_arg)
          original_pairs = h.raw.to_a
          new_pairs = []
          processed = 0
          begin
            original_pairs.each do |k, v|
              nk = if hash_arg && !hash_arg.is_a?(NilObject) && hash_arg.key?(k)
                hash_arg[k]
              elsif block_arg && !block_arg.is_a?(NilObject)
                block_arg.invoke(context, [k])
              else
                k
              end
              new_pairs << [nk, v]
              processed += 1
            end
          rescue Ast::BreakException
            # break occurred mid-iteration: remaining pairs stay with original keys
          end
          h.clear_elements
          original_pairs[processed..].each { |k, v| h[k] = v }
          new_pairs.each { |k, v| h[k] = v }
          h
        end

        def hash_compare_by_identity(_, h)
          # Stub - Frozone doesn't support identity-based key comparison
          h
        end

        def hash_compare_by_identity_q(_, h)
          FalseObject::FALSE
        end

        def hash_ruby2_keywords_hash(_, h)
          h.ruby2_keywords = true if h.is_a?(HashObject)
          h
        end

        def hash_ruby2_keywords_hash_q(_, h)
          bool_object_for(h.is_a?(HashObject) && h.ruby2_keywords)
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
            mod.instance_variable_get(:@methods).each do |name, meth|
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
