module Frozone
  module Vm
    # VM Fiber object — wraps a Ruby Fiber for coroutine switching.
    # Each Frozone Fiber runs its block on a native Ruby Fiber, giving true
    # coroutine semantics. $! and $@ are fiber-local (saved/restored at each
    # resume/yield boundary).
    class FiberObject < ObjectObject
      FIBER_LOCAL_GLOBALS = %i[$! $@].freeze

      attr_accessor :blocking

      def initialize(block_obj, blocking: false, initial_storage: nil, frozone_thread_id: nil)
        super(Core.fiber_class || Core::OBJECT_CLASS)
        @block_obj = block_obj
        # Per-fiber snapshots of $! and $@ (start as nil)
        @fiber_globals = { :"$!" => NilObject::NIL, :"$@" => NilObject::NIL }
        @ruby_fiber = nil
        @alive = true
        @status = :created  # :created, :running, :suspended, :dead
        @blocking = blocking
        @is_root = false
        @raise_exception = nil  # pending exception to raise on next resume
        @kill_pending = false   # kill flag for fiber_kill
        @suspended_by_transfer = false  # true if last suspended by transfer (not Fiber.yield)
        # Track which native MRI thread owns this fiber for cross-thread detection
        @owner_thread = ::Thread.current
        # Track which Frozone (simulated) thread owns this fiber.
        # nil = main Frozone thread; otherwise object_id of Frozone Thread object.
        @frozone_owner_thread_id = frozone_thread_id
        # Storage: nil means inherit from parent, NilObject::NIL means empty (lazily initialized)
        @initial_storage = initial_storage
      end

      def self.root
        # Create a root fiber object representing the current thread's main fiber
        fo = allocate
        fo.instance_variable_set(:@class_object, Core.fiber_class || Core::OBJECT_CLASS)
        fo.instance_variable_set(:@block_obj, nil)
        fo.instance_variable_set(:@fiber_globals, { :"$!" => NilObject::NIL, :"$@" => NilObject::NIL })
        fo.instance_variable_set(:@ruby_fiber, ::Fiber.current)
        fo.instance_variable_set(:@alive, true)
        fo.instance_variable_set(:@status, :running)
        fo.instance_variable_set(:@is_root, true)
        fo.instance_variable_set(:@blocking, false)
        fo.instance_variable_set(:@raise_exception, nil)
        fo.instance_variable_set(:@kill_pending, false)
        fo.instance_variable_set(:@suspended_by_transfer, false)
        fo.instance_variable_set(:@owner_thread, ::Thread.current)
        fo
      end

      def alive? = @alive
      def status = @status

      # Transfer to this fiber (like resume but with flat-switch semantics)
      def transfer(outer_context, args)
        # Self-transfer: if the target is the current running fiber, just return NIL
        current_fiber_obj = ::Fiber[:frozone_fiber_obj] || (::Fiber[:frozone_root_fiber] ||= FiberObject.root)
        return NilObject::NIL if self.equal?(current_fiber_obj)

        # Transferring to root fiber: use native transfer to switch back
        if @is_root
          # Transfer to the root fiber via native transfer
          return transfer_to_root(args)
        end

        # Check: can't transfer to a fiber that was suspended by Fiber.yield (only resume can)
        if @status == :suspended && !@suspended_by_transfer
          raise FrozoneException.make(:FiberError, "attempt to transfer to a yielding fiber")
        end

        if @status == :running
          raise FrozoneException.make(:FiberError, "attempt to resume a running fiber")
        end

        do_transfer(outer_context, args)
      end

      def resume(outer_context, args)
        unless @alive
          raise FrozoneException.make(:FiberError, "dead fiber called")
        end

        if @status == :running
          # Distinguish: resuming the current fiber vs a fiber that's in the call chain
          current_fiber_obj = ::Fiber[:frozone_fiber_obj] || (::Fiber[:frozone_root_fiber] ||= FiberObject.root)
          if self.equal?(current_fiber_obj)
            raise FrozoneException.make(:FiberError, "current fiber called")
          end
          raise FrozoneException.make(:FiberError, "attempt to resume a resuming fiber")
        end

        do_resume(outer_context, args)
      end

      # Resume this fiber for the purpose of raising an exception (skips running-status check for root fiber)
      def resume_for_raise(outer_context)
        unless @alive
          raise FrozoneException.make(:FiberError, "dead fiber called")
        end

        if @status == :running
          raise FrozoneException.make(:FiberError, "double resume")
        end

        do_resume(outer_context, [])
      end

      # Schedule an exception to be raised on next resume
      def schedule_raise(exception)
        @raise_exception = exception
      end

      # Schedule a kill (uses a special exception that bypasses rescue)
      def schedule_kill
        @kill_pending = true
      end

      # Kill an unborn fiber (never resumed)
      def kill_unborn!
        @alive = false
        @status = :dead
      end

      private

      def do_resume(outer_context, args)
        # Cross-thread check: fibers can only be used from their owner (Frozone) thread.
        # CURRENT_FROZONE_THREAD_ID[0] is nil for the main thread, or the object_id of
        # the active Frozone Thread object when inside Thread#__run_block.
        current_fz_thread = Intrinsics::CURRENT_FROZONE_THREAD_ID[0]
        if current_fz_thread != @frozone_owner_thread_id
          raise FrozoneException.make(:FiberError, "fiber called across threads")
        end

        # Also check native MRI thread (for any real cross-thread usage)
        if @owner_thread && ::Thread.current != @owner_thread
          raise FrozoneException.make(:FiberError, "fiber called across threads")
        end

        # Swap outer $!/$@ with this fiber's saved values
        saved_outer = save_and_swap_globals(@fiber_globals)

        pending_raise = @raise_exception
        @raise_exception = nil
        kill_now = @kill_pending
        @kill_pending = false

        if @ruby_fiber.nil?
          bo = @block_obj
          self_fiber = self
          fc = Context.new
          init_storage = @initial_storage
          @ruby_fiber = ::Fiber.new do
            ::Fiber[:frozone_fiber] = ::Fiber.current
            ::Fiber[:frozone_fiber_obj] = self_fiber
            ::Fiber[:context] = fc
            # Always explicitly set storage to override MRI's fiber storage inheritance.
            # init_storage is a Ruby Hash ({sym => val}), or nil for empty.
            ::Fiber[:__frozone_storage__] = init_storage
            self_fiber.instance_variable_set(:@status, :running)
            begin
              bo.invoke(fc, args)
            end
          end
        end

        is_first_resume = @status == :created
        @status = :running
        @suspended_by_transfer = false

        begin
          if kill_now
            result = @ruby_fiber.raise(FiberKillException.new)
          elsif pending_raise
            result = @ruby_fiber.raise(pending_raise)
          elsif is_first_resume
            # First resume: args captured in the fiber block closure; no arg to pass
            result = @ruby_fiber.resume
          else
            # Subsequent resume: pass first arg as return value of Fiber.yield
            resume_val = args.is_a?(Array) ? (args.first || NilObject::NIL) : NilObject::NIL
            result = @ruby_fiber.resume(resume_val)
          end
          @alive = @ruby_fiber.alive?
          @status = @alive ? :suspended : :dead
          result.is_a?(ObjectObject) ? result : NilObject::NIL
        rescue FrozoneException => e
          @alive = false
          @status = :dead
          raise
        rescue FiberKillException
          @alive = false
          @status = :dead
          NilObject::NIL
        rescue ::FiberError => e
          # Cross-thread errors don't kill the fiber — it remains usable from the correct thread
          cross_thread = e.message.include?("across thread") || e.message.include?("called across")
          unless cross_thread
            @alive = false
            @status = :dead
          else
            @status = :suspended
          end
          raise FrozoneException.make(:FiberError, e.message)
        ensure
          restore_and_save_globals(saved_outer, @fiber_globals)
        end
      end

      def do_transfer(outer_context, args)
        # Cross-thread check: fibers can only be used from their owner (Frozone) thread.
        current_fz_thread = Intrinsics::CURRENT_FROZONE_THREAD_ID[0]
        if current_fz_thread != @frozone_owner_thread_id
          raise FrozoneException.make(:FiberError, "fiber called across threads")
        end

        # Also check native MRI thread (for any real cross-thread usage)
        if @owner_thread && ::Thread.current != @owner_thread
          raise FrozoneException.make(:FiberError, "fiber called across threads")
        end

        # Swap outer $!/$@ with this fiber's saved values
        saved_outer = save_and_swap_globals(@fiber_globals)

        pending_raise = @raise_exception
        @raise_exception = nil

        is_first_transfer = @ruby_fiber.nil?

        if is_first_transfer
          bo = @block_obj
          self_fiber = self
          fc = Context.new
          init_storage = @initial_storage
          @ruby_fiber = ::Fiber.new do
            ::Fiber[:frozone_fiber] = ::Fiber.current
            ::Fiber[:frozone_fiber_obj] = self_fiber
            ::Fiber[:context] = fc
            ::Fiber[:__frozone_storage__] = init_storage
            self_fiber.instance_variable_set(:@status, :running)
            begin
              bo.invoke(fc, args)
            end
          end
        end

        @status = :running
        @suspended_by_transfer = false

        begin
          if pending_raise
            result = @ruby_fiber.raise(pending_raise)
          elsif is_first_transfer
            # First transfer: args captured in closure, no arg to native transfer
            result = @ruby_fiber.transfer
          else
            # Subsequent transfer: pass the first arg as return value for the previous transfer call
            transfer_val = args.is_a?(Array) ? (args.first || NilObject::NIL) : NilObject::NIL
            result = @ruby_fiber.transfer(transfer_val)
          end
          @alive = @ruby_fiber.alive?
          @status = @alive ? :suspended : :dead
          @suspended_by_transfer = @alive
          result.is_a?(ObjectObject) ? result : NilObject::NIL
        rescue FrozoneException => e
          @alive = false
          @status = :dead
          raise
        rescue ::FiberError => e
          cross_thread = e.message.include?("across thread") || e.message.include?("called across")
          unless cross_thread
            @alive = false
            @status = :dead
          else
            @status = :suspended
            @suspended_by_transfer = true
          end
          raise FrozoneException.make(:FiberError, e.message)
        ensure
          restore_and_save_globals(saved_outer, @fiber_globals)
        end
      end

      def transfer_to_root(args)
        # Transfer to the root fiber via native Fiber transfer.
        # Returns the value passed when we're transferred back.
        val = args.is_a?(Array) ? (args.first || NilObject::NIL) : NilObject::NIL
        result = @ruby_fiber.transfer(val)
        result.is_a?(ObjectObject) ? result : NilObject::NIL
      rescue ::FiberError => e
        raise FrozoneException.make(:FiberError, e.message)
      end

      # Save current GLOBALS values for fiber_globals keys into saved_outer,
      # then replace GLOBALS with fiber_globals values.
      # Returns the saved outer values.
      def save_and_swap_globals(fiber_globals)
        saved = {}
        FIBER_LOCAL_GLOBALS.each do |key|
          saved[key] = GLOBALS[key]
          GLOBALS[key] = fiber_globals.fetch(key, NilObject::NIL)
        end
        saved
      end

      # Save current GLOBALS back into fiber_globals, then restore outer values.
      def restore_and_save_globals(saved_outer, fiber_globals)
        FIBER_LOCAL_GLOBALS.each do |key|
          fiber_globals[key] = GLOBALS[key]
          GLOBALS[key] = saved_outer[key]
        end
      end
    end

    # Special exception class for fiber kill that is NOT caught by rescue Exception
    # This is a native Ruby exception (not a FrozoneException) so Frozone's rescue
    # blocks in user code won't catch it, but ensure blocks will still run.
    class FiberKillException < ::Exception; end
  end
end
