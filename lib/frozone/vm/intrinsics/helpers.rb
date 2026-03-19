# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        def maybe_warn_deprecated_constant(context, owner, name)
          return unless owner.is_a?(ModuleObject)
          deprecated = owner.instance_variable_get(:@deprecated_constants)
          return unless deprecated&.key?(name)
          return unless deprecated_warnings_enabled?
          mod_name = owner.full_name || "<anonymous>"
          Frozone::Vm.emit_warning(context, "constant #{mod_name}::#{name} is deprecated")
        end

        def normalize_ivar(name)
          sym = name.is_a?(SymbolObject) ? name.raw : name.raw.to_sym
          :"@#{sym.to_s.delete_prefix('@')}"
        end

        # Validate ivar name and return the normalized ivar Symbol.
        # Raises NameError if name is not a valid ivar name.
        def validated_ivar(name, receiver = NilObject::NIL)
          s = name.raw.to_s
          raise ivar_name_error("'#{s}' is not allowed as an instance variable name", name, receiver) unless s.start_with?('@') && s.length > 1
          normalize_ivar(name)
        end

        # Raise FrozenError if v is frozen.
        def check_frozen!(v)
          return unless v.frozen_object?
          raise FrozoneException.make(:FrozenError, "can't modify frozen #{frozone_class_name(v)}: #{v.inspect rescue v.object_id}")
        end

        # Rescue mri_excs and reraise as the equivalent FrozoneException.
        # MRI class name maps to Frozone symbol via '::' -> '__' substitution.
        # Use as: to override when multiple exceptions fold to one Frozone type.
        def reraise(*mri_excs, as: nil)
          yield
        rescue *mri_excs => e
          raise FrozoneException.make(as || e.class.name.gsub('::', '__').to_sym, e.message)
        end

        def collect_method_names(v, include_super, singleton_only_when_false: false, &visibility_ok)
          seen = {}
          result = []

          add_from = lambda do |mod|
            mod.methods_table.each do |name, meth|
              next if seen[name]
              seen[name] = true
              next if meth == ModuleObject::UNDEF_SENTINEL
              next unless visibility_ok.call(meth.visibility)
              result << SymbolObject.from(name)
            end
          end

          if include_super
            sources = []
            if v.eigenclass
              sc = v.singleton_class
              sources << sc
              sc.modules.reverse_each { |m| sources << m }
            end
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
            sources.each { |mod| add_from.call(mod) }
          elsif singleton_only_when_false
            # methods(false) semantics: ONLY the eigenclass's own methods_table
            add_from.call(v.eigenclass) if v.eigenclass
          else
            # public_methods(false) / private_methods(false) semantics: walk the singleton
            # class's ancestor list, including all singleton classes and modules (extended
            # modules), then the first real class's own methods_table only.
            if v.eigenclass
              v.singleton_class.ancestors_list.each do |ancestor|
                if ancestor.is_a?(ClassObject) && !ancestor.is_singleton_class
                  # First non-singleton class: include only its own methods_table, then stop
                  add_from.call(ancestor)
                  break
                else
                  # Singleton class or module: include fully
                  add_from.call(ancestor)
                end
              end
            else
              # No singleton class: include only the object's own class methods
              add_from.call(v.class_object)
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

        # Collect all refinements from mod and its ancestors (depth-first, included modules).
        # Returns a hash mapping klass.object_id => refinement_module.
        def collect_refinements_from_module(mod)
          refs = {}
          return refs unless mod.is_a?(ModuleObject)
          # Collect from the module itself
          refine_map = mod.instance_variable_get(:@refinements)
          if refine_map.is_a?(::Hash)
            refine_map.each do |klass, ref_mod|
              refs[klass.object_id] ||= ref_mod
            end
          end
          # Depth-first through included modules (not prepended, not superclass)
          mod.modules.each do |inc_mod|
            collect_refinements_from_module(inc_mod).each do |klass_id, ref_mod|
              refs[klass_id] ||= ref_mod
            end
          end
          refs
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

        # Collect raw caller frame data for kernel_caller / kernel_caller_locations.
        # Returns an array of [call_site, method_name] pairs, starting from the
        # last frame whose current_method name matches `anchor_method_name`.
        def collect_caller_frames(context, anchor_method_name)
          all_frames = context.frames.reverse
          last_anchor_idx = all_frames.rindex { |f| f.current_method&.name == anchor_method_name } || -1
          base = [last_anchor_idx, 0].max
          frames = []
          i = base
          while i < all_frames.length - 1
            call_site = all_frames[i].incoming_call_site || "unknown:0"
            meth = all_frames[i + 1].current_method&.name&.to_s || "block"
            frames << [call_site, meth]
            i += 1
          end
          frames
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

        def exception_tty_check(_context = NilObject::NIL)
          $stderr.isatty ? TrueObject::TRUE : FalseObject::FALSE
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
              break if c_cause.is_a?(NilObject)
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
          elsif !backtrace_arg.is_a?(NilObject)
            exc_obj.set_ivar(:@backtrace, backtrace_arg)
            exc_obj.set_ivar(:@_has_locations, TrueObject::TRUE)
          else
            set_exc_backtrace(exc_obj, context)
          end
        end

        def frozone_class_name(obj)
          obj.is_a?(ObjectObject) ? (obj.class_object&.name || "Object") : obj.class.name
        end

        # ObjectSpace

        def objectspace_each_object(context, klass_obj, block)
          return IntegerObject.new(0) if block.is_a?(NilObject)
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
          reraise(RangeError) do
            obj = ::ObjectSpace._id2ref(id)
            obj.is_a?(Frozone::Vm::ObjectObject) ? obj : NilObject::NIL
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
