# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      # Thread-local global isolation: save $_ and $? before running Thread body.
      THREAD_SAVED_LOCALS = {}

      class << self
        def fiber_yield(_, _receiver, args) = ::Fiber.yield(args.raw.first || FNIL)
        def fiber_alive(_, fiber_obj) = n2f_bool(fiber_obj.is_a?(FiberObject) && fiber_obj.alive?)
        def thread_run_block(context, block_obj) = (bo = block_obj.is_a?(ProcObject) ? block_obj.block_object : block_obj; bo.invoke(context, [], thread_boundary: true))
        def fiber_resume(context, fiber_obj, args) = (raise FrozoneException.make(:TypeError, "can't resume a non-Fiber object") unless fiber_obj.is_a?(FiberObject); fiber_obj.resume(context, args.raw))
        def fiber_transfer(context, fiber_obj, args) = (raise FrozoneException.make(:TypeError, "can't transfer to a non-Fiber object") unless fiber_obj.is_a?(FiberObject); fiber_obj.transfer(context, args.raw))
        def fiber_current(_context, _receiver) = (::Fiber[:frozone_fiber_obj] || (::Fiber[:frozone_root_fiber] ||= FiberObject.root))
        def fiber_blocking_q(_, fiber_obj) = (fiber_obj.is_a?(FiberObject) ? n2f_bool(fiber_obj.blocking) : FFALSE)

        def thread_save_reset_locals(_, thread_obj)
          THREAD_SAVED_LOCALS[thread_obj.object_id] = {
            dollar_underscore: GLOBALS.fetch(:"$_", FNIL),
            dollar_question: GLOBALS.fetch(:"$?", FNIL),
            frozone_thread_id: CURRENT_FROZONE_THREAD_ID[0]
          }
          GLOBALS[:"$_"] = FNIL
          GLOBALS.delete(:"$?")
          CURRENT_FROZONE_THREAD_ID[0] = thread_obj.object_id
          FNIL
        end

        def thread_restore_locals(_, thread_obj)
          saved = THREAD_SAVED_LOCALS.delete(thread_obj.object_id) || {}
          GLOBALS[:"$_"] = saved[:dollar_underscore] || FNIL
          if saved[:dollar_question] && !fnil?(saved[:dollar_question])
            GLOBALS[:"$?"] = saved[:dollar_question]
          else
            GLOBALS.delete(:"$?")
          end
          CURRENT_FROZONE_THREAD_ID[0] = saved.key?(:frozone_thread_id) ? saved[:frozone_thread_id] : nil
          FNIL
        end

        def fiber_new(_, klass, block_obj, blocking_val = FNIL, storage_val = FNIL)
          raise FrozoneException.make(:ArgumentError, "tried to create Fiber object without a block") if fnil?(block_obj)
          bo = block_obj.is_a?(ProcObject) ? block_obj.block_object : block_obj
          fiber_klass = klass.is_a?(ClassObject) ? klass : (Core.fiber_class || Core::OBJECT_CLASS)
          blocking = blocking_val.truthy?

          # Process storage: SymbolObject(:__unset__) = inherit, NilObject = empty/lazy, HashObject = explicit
          init_storage = if fsym?(storage_val) && storage_val.raw == :__unset__
                           # Default: inherit parent's storage by copying
                           current_storage = ::Fiber[:__frozone_storage__]
                           (current_storage && !current_storage.empty?) ? current_storage.dup : nil
                         elsif fnil?(storage_val)
                           # storage: nil means start with empty (lazily initialized on first write)
                           nil
                         elsif fhash?(storage_val)
                           raise FrozoneException.make(:FrozenError, "can't modify frozen Hash") if storage_val.frozen_object?
                           mri_hash = {}
                           storage_val.raw.each do |k, v|
                             key_obj = fsym?(k) ? k : nil
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

        def fiber_set_blocking(_, fiber_obj, val)
          return FNIL unless fiber_obj.is_a?(FiberObject)
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
          return n2f_str("#<Fiber: (root)>") unless fiber_obj.is_a?(FiberObject)
          addr = "0x%016x" % fiber_obj.object_id
          status_name = FIBER_STATUS_NAMES[fiber_obj.status] || fiber_obj.status.to_s
          # Include a source location placeholder to match expected pattern
          source = "(unknown)"
          n2f_str("#<Fiber:#{addr} #{source} (#{status_name})>")
        end

        def fiber_class_blocking_q(_, _receiver)
          # Returns false for non-blocking mode, or 1 for blocking depth
          current = ::Fiber[:frozone_fiber_obj]
          if current.is_a?(FiberObject) && current.blocking
            n2f_int(1)
          else
            FFALSE
          end
        end

        def fiber_raise(context, fiber_obj, msg = FNIL, message_arg = FNIL, backtrace_arg = FNIL, cause_arg = FNIL)
          raise FrozoneException.make(:FiberError, "cannot raise exception on unborn fiber") if fiber_obj.is_a?(FiberObject) && fiber_obj.status == :created

          # Validate cause: arg in calling context (TypeError/ArgumentError raised here, not in fiber)
          no_cause_sentinel = fsym?(cause_arg) && cause_arg.raw == :__raise_no_cause__
          no_arg_sentinel = fsym?(msg) && msg.raw == :__raise_no_arg__
          explicit_cause = !fnil?(cause_arg) && !no_cause_sentinel

          if no_arg_sentinel && explicit_cause
            raise FrozoneException.make(:ArgumentError, "only cause is given with no arguments")
          end

          if explicit_cause && !fnil?(cause_arg)
            raise FrozoneException.make(:TypeError, "exception object expected") unless exception_instance?(cause_arg)
          end

          # If the target fiber is the currently running fiber (or its parent in the resume chain),
          # raise directly rather than scheduling (avoids "double resume" error).
          if fiber_obj.is_a?(FiberObject) && fiber_obj.status == :running
            kernel_raise(context, FNIL, msg, message_arg, backtrace_arg, cause_arg)
            return FNIL
          end

          raise FrozoneException.make(:FiberError, "dead fiber called") if !fiber_obj.is_a?(FiberObject) || !fiber_obj.alive?

          exc = begin
            kernel_raise(context, FNIL, msg, message_arg, backtrace_arg, cause_arg)
            FrozoneException.make(:RuntimeError, "")  # fallback if kernel_raise didn't raise (shouldn't happen)
          rescue FrozoneException => e
            e
          end

          fiber_obj.schedule_raise(exc)
          fiber_obj.resume_for_raise(context)
        end

        def fiber_kill(context, fiber_obj)
          return FNIL unless fiber_obj.is_a?(FiberObject)
          # Kill unborn fiber: just mark as dead
          if fiber_obj.status == :created
            fiber_obj.kill_unborn!
            return FNIL
          end
          return FNIL unless fiber_obj.alive?
          begin
            fiber_obj.schedule_kill
            fiber_obj.resume_for_raise(context)
          rescue FrozoneException
            # fiber terminated
          rescue ::FiberError
            # fiber error during kill
          end
          FNIL
        end

        def fiber_storage_coerce_key(context, key_obj)
          return key_obj.raw if fsym?(key_obj)
          if fstr?(key_obj)
            return key_obj.raw.to_sym
          end
          # Try to_str for string-like objects
          begin
            str = key_obj.dispatch(context, :to_str, [], {})
            return str.raw.to_sym if fstr?(str)
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
          val.nil? ? FNIL : val
        end

        def fiber_storage_set(context, _receiver, key_obj, val)
          sym = fiber_storage_coerce_key(context, key_obj)
          if fnil?(val)
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
            ho[n2f_sym(sym)] = val
          end
          ho
        end

        # Set the current fiber's storage from a Frozone value (for Fiber#storage=)
        def fiber_storage_hash_set(_context, fiber_obj, val)
          current = ::Fiber[:frozone_fiber_obj] || (::Fiber[:frozone_root_fiber] ||= FiberObject.root)
          unless fiber_obj.equal?(current)
            raise FrozoneException.make(:ArgumentError, "Fiber storage can only be accessed from the Fiber it belongs to")
          end
          if fnil?(val)
            ::Fiber[:__frozone_storage__] = nil
          elsif fhash?(val)
            raise FrozoneException.make(:FrozenError, "can't modify frozen Hash") if val.frozen_object?
            mri_hash = {}
            val.raw.each do |k, v|
              unless fsym?(k)
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
      end
    end
  end
end
