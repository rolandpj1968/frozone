# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        def frozone_class_name(obj) = obj.is_a?(ObjectObject) ? (obj.class_object&.name || "Object") : obj.class.name

        def maybe_warn_deprecated_constant(context, owner, name)
          return unless owner.is_a?(ModuleObject)
          deprecated = owner.instance_variable_get(:@deprecated_constants)
          return unless deprecated&.key?(name)
          return unless deprecated_warnings_enabled?
          mod_name = owner.full_name || "<anonymous>"
          Frozone::Vm.emit_warning(context, "constant #{mod_name}::#{name} is deprecated")
        end

        def normalize_ivar(name)
          sym = fsym?(name) ? name.raw : name.raw.to_sym
          :"@#{sym.to_s.delete_prefix('@')}"
        end

        # Validate ivar name and return the normalized ivar Symbol.
        # Raises NameError if name is not a valid ivar name.
        def validated_ivar(name, receiver = FNIL)
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
              result << n2f_sym(name)
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

          n2f_arr(result)
        end

        def module_set_visibility(context, receiver, names, vis)
          name_list = names.raw
          if name_list.empty?
            receiver.current_visibility = vis
            return FNIL
          end
          # Handle array as single argument: private([:foo, :bar]) → flatten one level
          if name_list.size == 1 && farray?(name_list[0])
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
                exc.vm_object.set_ivar(:@name, n2f_sym(name))
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
            n2f_sym(name)
          end
          result.size == 1 ? result[0] : n2f_arr(result)
        end

        LOAD_EXTENSIONS = %w[.rb .so .bundle .dylib].freeze

        def load_path_dir_str(dir_obj)
          if dir_obj.respond_to?(:raw) && dir_obj.raw.is_a?(::String)
            dir_obj.raw
          else
            ctx = Fiber[:context]
            return nil unless ctx
            begin
              result = dir_obj.dispatch(ctx, :to_path, [], {})
              result.respond_to?(:raw) ? result.raw : nil
            rescue StandardError
              nil
            end
          end
        end

        def load_add_rb(path)
          LOAD_EXTENSIONS.any? { |ext| path.end_with?(ext) } ? path : "#{path}.rb"
        end

        def resolve_load_path(path)
          path = ::File.expand_path(path) if path.start_with?('~')
          path_rb = load_add_rb(path)

          if path.start_with?('/') || path.start_with?('./') || path.start_with?('../')
            # Absolute or explicit CWD-relative path: expand, don't search $LOAD_PATH
            expanded = ::File.expand_path(path_rb)
            return expanded if ::File.exist?(expanded)
            return nil
          end

          # Bare/relative path: search $LOAD_PATH only (NOT CWD)
          # For native extensions (.so/.bundle/.dylib), also try .rb stub in each dir
          path_rb_alt = if path_rb =~ /\.(so|bundle|dylib)\z/
            path_rb.sub(/\.(so|bundle|dylib)\z/, '.rb')
          end
          load_path = GLOBALS[:"$LOAD_PATH"]
          load_path&.raw&.each do |dir_obj|
            dir = load_path_dir_str(dir_obj)
            next unless dir
            # Try .rb stub before native extension (allows our stubs to override .so files)
            if path_rb_alt
              full_rb = ::File.expand_path(::File.join(dir, path_rb_alt))
              return full_rb if ::File.exist?(full_rb)
            end
            full = ::File.expand_path(::File.join(dir, path_rb))
            return full if ::File.exist?(full)
          end
          nil
        end

        def load_path_candidates(path_rb)
          load_path = GLOBALS[:"$LOAD_PATH"]
          return [] unless load_path
          load_path.raw.filter_map do |dir_obj|
            dir = load_path_dir_str(dir_obj)
            next unless dir
            ::File.expand_path(::File.join(dir, path_rb))
          end
        end

        def no_method_receiver_desc(receiver)
          ctx = Fiber[:context]
          if receiver.equal?(FNIL)
            "nil"
          elsif receiver.equal?(FTRUE)
            "true"
          elsif receiver.equal?(FFALSE)
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
          if fsym?(name)
            name.raw
          elsif fstr?(name)
            name.raw.to_sym
          else
            klass = frozone_class_name(name)
            raise FrozoneException.make(:TypeError, "#{klass} is not a symbol nor a string")
          end
        end

        def sym_name(name_obj)
          return name_obj.raw if fsym?(name_obj)
          return name_obj.raw.to_sym if fstr?(name_obj)
          type_name = name_obj.is_a?(ObjectObject) ? (name_obj.class_object&.name || "Object") : name_obj.class.name
          raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string")
        end

        # Like sym_name but also tries to_str on arbitrary objects (for const_get, module_function, etc.)
        def sym_name_coercing(context, name_obj)
          return name_obj.raw if fsym?(name_obj)
          return name_obj.raw.to_sym if fstr?(name_obj)
          type_name = name_obj.is_a?(ObjectObject) ? (name_obj.class_object&.name || "Object") : name_obj.class.name
          # Try to_str
          has_to_str = begin
            name_obj.dispatch(context, :respond_to?, [n2f_sym(:to_str)], {}).truthy?
          rescue FrozoneException
            false
          end
          raise FrozoneException.make(:TypeError, "#{type_name} is not a symbol nor a string") unless has_to_str
          result = name_obj.dispatch(context, :to_str, [], {})
          raise FrozoneException.make(:TypeError, "can't convert #{type_name} into String") unless fstr?(result)
          result.raw.to_sym
        end

        def alias_method_coerce_name(context, name_obj)
          if fsym?(name_obj)
            name_obj.raw
          elsif fstr?(name_obj)
            name_obj.raw.to_sym
          elsif fobj?(name_obj)
            # Check respond_to?(:to_str) — if not defined, raise TypeError
            has_to_str = begin
              name_obj.dispatch(context, :respond_to?, [n2f_sym(:to_str)], {}).truthy?
            rescue FrozoneException
              false
            end
            raise FrozoneException.make(:TypeError, "#{name_obj.class_object&.name} is not a symbol nor a string") unless has_to_str
            # Call to_str; if it raises, propagate the exception as-is
            result = name_obj.dispatch(context, :to_str, [], {})
            raise FrozoneException.make(:TypeError, "can't convert #{name_obj.class_object&.name} into String") unless fstr?(result)
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
          # Collect from the module itself — stored as Frozone ivar @__refinements__
          # (a Frozone HashObject with IntObject keys = klass.object_id values)
          refine_map_obj = mod.get_ivar(:@__refinements__)
          if fhash?(refine_map_obj)
            refine_map_obj.raw.each do |k, v|
              klass_id = fint?(k) ? k.raw : k
              refs[klass_id] ||= v if v.is_a?(ModuleObject)
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
            outer = all_frames[i + 1]
            meth = caller_method_name(outer.current_method, outer.the_self)
            frames << [call_site, meth]
            i += 1
          end
          frames
        end

        # Format method name with module qualifier (e.g. "Kernel#tap", "String#upcase").
        # Matches MRI's caller format for methods defined in named modules/classes.
        # Class methods use "." separator (e.g. "Foo.bar"); instance methods use "#".
        def caller_method_name(method, the_self = nil)
          return "block" unless method.is_a?(Method)
          name = method.name.to_s
          owner = method.scopes.last
          return name unless owner.is_a?(ModuleObject)
          mod_name = owner.full_name
          return name if mod_name.nil?
          separator = the_self.is_a?(ModuleObject) ? "." : "#"
          "#{mod_name}#{separator}#{name}"
        end

        def exception_caller_string(context)
          # Return a caller location string for full_message when exception has no backtrace.
          # We want the call site where full_message was invoked, which is stored as the
          # incoming_call_site of the full_message frame (last internal frame we skip over).
          all_frames = context.frames.reverse
          # Skip internal frames (full_message, detailed_message, exception_caller_string)
          i = 0
          skip = %i[full_message detailed_message exception_caller_string __full_message_dm__ __format_single_full_message__]
          i += 1 while i < all_frames.length && skip.include?(all_frames[i].current_method&.name)
          return FNIL if i.zero?
          # The last skipped frame (i-1) has incoming_call_site = where full_message was called from
          loc = all_frames[i - 1].incoming_call_site
          return FNIL unless loc
          outer_name = i < all_frames.length ? caller_method_name(all_frames[i].current_method, all_frames[i].the_self) : "<main>"
          n2f_str("#{loc}:in '#{outer_name}'")
        end

        def exception_tty_check(_context = FNIL)
          $stderr.isatty ? FTRUE : FFALSE
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
            meth = caller_method_name(outer_frame.current_method, outer_frame.the_self) || "<main>"
            bt << n2f_str("#{loc}:in '#{meth}'", frozen: true)
            i += 1
          end
          # Outermost frame: only include if no other entries added (single-frame case).
          # In multi-frame cases, the outermost (main) frame has no meaningful call site
          # and its location is already captured by the inner frame's call-site entry.
          if bt.empty? && i < all_frames.length
            outer = all_frames[i]
            loc = outer.incoming_call_site || (outer.current_method&.source_location) || "unknown:0"
            bt << n2f_str("#{loc}:in '<main>'", frozen: true)
          end
          n2f_arr(bt)
        end

        def set_exc_backtrace(exc_obj, context)
          bt = build_vm_backtrace(context)
          unless fnil?(exc_obj)
            exc_obj.set_ivar(:@backtrace, bt)
            exc_obj.set_ivar(:@_has_locations, FTRUE)
          end
        end

        def exception_instance?(obj)
          frozone_exc_class = Core::OBJECT_CLASS.get_constant(:Exception)
          return false unless frozone_exc_class && obj.is_a?(ObjectObject)
          c = obj.class_object
          while c
            return true if c.equal?(frozone_exc_class)
            c = fclass?(c) ? c.superclass : nil
          end
          false
        end

        # Apply auto-cause ($!) to an exception before raising it internally.
        # Skips if: no current exception, self-cause, or circular.
        def apply_auto_cause(exc_obj)
          current_exc = GLOBALS[:"$!"]
          return unless current_exc && !fnil?(current_exc)
          return if current_exc.equal?(exc_obj)
          return if validate_cause(current_exc, exc_obj, auto_cause: true) == :skip
          exc_obj.set_ivar(:@cause, current_exc)
        end

        def validate_cause(cause, exc_obj, auto_cause: false)
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
              break if fnil?(c_cause)
              if c_cause.equal?(exc_obj)
                return :skip if auto_cause
                raise FrozoneException.make(:ArgumentError, "circular causes")
              end
              c = c_cause
            end
          end
        end

        def apply_backtrace(exc_obj, backtrace_arg, context)
          if farray?(backtrace_arg)
            exc_obj.set_ivar(:@backtrace, backtrace_arg)
            # Detect if elements are Thread::Backtrace::Location objects (not plain strings)
            first = backtrace_arg.raw.first
            has_locs = first.is_a?(ObjectObject) && !fstr?(first)
            exc_obj.set_ivar(:@_has_locations, has_locs ? FTRUE : FFALSE)
          elsif !fnil?(backtrace_arg)
            exc_obj.set_ivar(:@backtrace, backtrace_arg)
            exc_obj.set_ivar(:@_has_locations, FTRUE)
          else
            set_exc_backtrace(exc_obj, context)
          end
        end

        # ObjectSpace

        def objectspace_each_object(context, klass_obj, block)
          return n2f_int(0) if fnil?(block)
          klass = fnil?(klass_obj) ? nil : klass_obj
          count = 0
          ::ObjectSpace.each_object(Frozone::Vm::ObjectObject) do |obj|
            next if klass && object_is_a(context, obj, klass).equal?(FFALSE)
            block.invoke(context, [obj])
            count += 1
          end
          n2f_int(count)
        rescue StandardError
          n2f_int(0)
        end

        def objectspace_define_finalizer(context, obj, proc_arg, block)
          # Non-reference objects (immediate values) cannot have finalizers
          if fint?(obj) || fsym?(obj) || fnil?(obj) ||
             ftrue?(obj) || ffalse?(obj)
            klass = frozone_class_name(obj)
            raise FrozoneException.make(:ArgumentError, "wrong argument type #{klass} (expected non-immediate)")
          end
          callable = if !block.nil? && !fnil?(block)
                       block
                     elsif !proc_arg.nil? && !fnil?(proc_arg)
                       proc_arg
                     else
                       raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given 1, expected 2)")
                     end
          # Check respond_to?(:call)
          responds = begin
            result = callable.dispatch(context, :respond_to?, [n2f_sym(:call)], {})
            result.equal?(FTRUE)
          rescue FrozoneException
            fblock?(callable) || fproc?(callable) || fbound?(callable)
          end
          unless responds
            klass = frozone_class_name(callable)
            raise FrozoneException.make(:ArgumentError, "wrong argument type #{klass} (expected Proc)")
          end
          # Return [0, proc] as MRI does
          n2f_arr([n2f_int(0), callable])
        end

        def objectspace_garbage_collect(_)
          ::GC.start
          FNIL
        end

        def objectspace_undefine_finalizer(context, obj)
          is_frozen = begin
            obj.dispatch(context, :frozen?, [], {}).equal?(FTRUE)
          rescue FrozoneException
            false
          end
          if is_frozen
            klass_name = frozone_class_name(obj)
            raise FrozoneException.make(:FrozenError, "can't modify frozen #{klass_name}")
          end
          obj
        end

        def objectspace_id2ref(_, id_obj)
          id = fint?(id_obj) ? id_obj.raw : id_obj.raw.to_i
          reraise(RangeError) do
            obj = ::ObjectSpace._id2ref(id)
            obj.is_a?(Frozone::Vm::ObjectObject) ? obj : FNIL
          end
        end

        def objectspace_count_objects(_, result_obj)
          counts = ::ObjectSpace.count_objects
          h = {
            n2f_sym(:TOTAL) => n2f_int(counts[:TOTAL] || 0),
            n2f_sym(:FREE) => n2f_int(counts[:FREE] || 0),
            n2f_sym(:T_OBJECT) => n2f_int(counts[:T_OBJECT] || 0),
            n2f_sym(:T_CLASS) => n2f_int(counts[:T_CLASS] || 0),
            n2f_sym(:T_MODULE) => n2f_int(counts[:T_MODULE] || 0),
            n2f_sym(:T_FLOAT) => n2f_int(counts[:T_FLOAT] || 0),
            n2f_sym(:T_STRING) => n2f_int(counts[:T_STRING] || 0),
            n2f_sym(:T_REGEXP) => n2f_int(counts[:T_REGEXP] || 0),
            n2f_sym(:T_ARRAY) => n2f_int(counts[:T_ARRAY] || 0),
            n2f_sym(:T_HASH) => n2f_int(counts[:T_HASH] || 0),
            n2f_sym(:T_STRUCT) => n2f_int(counts[:T_STRUCT] || 0),
            n2f_sym(:T_BIGNUM) => n2f_int(0),
            n2f_sym(:T_FILE) => n2f_int(counts[:T_FILE] || 0),
            n2f_sym(:T_DATA) => n2f_int(counts[:T_DATA] || 0),
            n2f_sym(:T_MATCH) => n2f_int(counts[:T_MATCH] || 0),
            n2f_sym(:T_COMPLEX) => n2f_int(counts[:T_COMPLEX] || 0),
            n2f_sym(:T_RATIONAL) => n2f_int(counts[:T_RATIONAL] || 0),
            n2f_sym(:T_NIL) => n2f_int(0),
            n2f_sym(:T_TRUE) => n2f_int(0),
            n2f_sym(:T_FALSE) => n2f_int(0),
            n2f_sym(:T_SYMBOL) => n2f_int(counts[:T_SYMBOL] || 0),
            n2f_sym(:T_FIXNUM) => n2f_int(0),
            n2f_sym(:T_UNDEF) => n2f_int(0),
            n2f_sym(:T_IMEMO) => n2f_int(0),
            n2f_sym(:T_NODE) => n2f_int(0),
            n2f_sym(:T_ICLASS) => n2f_int(0),
            n2f_sym(:T_ZOMBIE) => n2f_int(0)
          }
          n2f_hash(h.transform_keys { |k| k })
        end

        # Self-hosting helpers: minimal Frozone::Vm::Vm proxy for Frozone-land evaluation

        def kernel_vm_initialize(_, vm_obj, options_obj)
          vm_obj.set_ivar(:@options, options_obj)
          vm_obj
        end

        def kernel_run_vm(_, vm_obj)
          fl_options = vm_obj.get_ivar(:@options)
          opts = fhash?(fl_options) ? fl_options.raw : {}

          scripts_obj = opts[n2f_sym(:scripts)]
          argv_obj    = opts[n2f_sym(:argv)]

          scripts = farray?(scripts_obj) ? scripts_obj.raw.map { |s| fstr?(s) ? s.raw : s.to_s } : []
          argv    = farray?(argv_obj)    ? argv_obj.raw.map    { |a| fstr?(a) ? a.raw : a.to_s } : []

          # Set Frozone-land ARGV for the inner script
          script_argv = scripts.empty? ? (argv[1..] || []) : []
          Core::OBJECT_CLASS.set_constant(:ARGV, n2f_arr(script_argv.map { |a| n2f_str(a) }))

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
                exit(fint?(status_obj) ? status_obj.raw : 0)
              end
            end
            raise
          end

          FNIL
        end

        # ENV intrinsics — direct MRI ENV access

        def env_key?(_, key) = n2f_bool(ENV.key?(key.raw))
        def env_value?(_, value) = n2f_bool(ENV.value?(value.raw))
        def env_keys(_) = n2f_arr(ENV.keys.map { |k| n2f_str(k) })
        def env_values(_) = n2f_arr(ENV.values.map { |v| n2f_str(v) })
        def env_size(_) = n2f_int(ENV.size)
        def env_pairs(_) = n2f_arr(ENV.map { |k, v| n2f_arr([n2f_str(k), n2f_str(v)]) })
        def env_to_hash(_) = n2f_hash(ENV.to_h { |k, v| [n2f_str(k), n2f_str(v)] })

        def env_get(_, key)
          val = ENV[key.raw]
          val.nil? ? FNIL : n2f_str(val)
        end

        def env_set(_, key, value)
          ENV[key.raw] = value.raw
          value
        end

        def env_delete(_, key)
          val = ENV.delete(key.raw)
          val.nil? ? FNIL : n2f_str(val)
        end

        def env_key(_, value)
          k = ENV.key(value.raw)
          k.nil? ? FNIL : n2f_str(k)
        end

        def env_clear(_)
          ENV.clear
          FNIL
        end
      end
    end
  end
end
