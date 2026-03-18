module Frozone
  module Vm
    # VM Fiber object — wraps a Ruby Fiber for coroutine switching.
    # Each Frozone Fiber runs its block on a native Ruby Fiber, giving true
    # coroutine semantics. $! and $@ are fiber-local (saved/restored at each
    # resume/yield boundary).
    class FiberObject < ObjectObject
      FIBER_LOCAL_GLOBALS = %i[$! $@].freeze

      attr_accessor :blocking

      def initialize(block_obj, blocking: false, initial_storage: nil)
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
        fo
      end

      def alive? = @alive
      def status = @status

      # Transfer to this fiber (like resume but from any fiber context)
      def transfer(outer_context, args)
        # Transferring to root fiber when already at root level returns nil
        return NilObject::NIL if @is_root
        resume(outer_context, args)
      rescue FrozoneException => e
        raise
      end

      def resume(outer_context, args)
        unless @alive
          raise FrozoneException.make(:FiberError, "dead fiber called")
        end

        if @status == :running
          raise FrozoneException.make(:FiberError, "double resume")
        end

        # Swap outer $!/$@ with this fiber's saved values
        saved_outer = save_and_swap_globals(@fiber_globals)

        pending_raise = @raise_exception
        @raise_exception = nil

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

        @status = :running

        begin
          if pending_raise
            result = @ruby_fiber.raise(pending_raise)
          else
            result = @ruby_fiber.resume
          end
          @alive = @ruby_fiber.alive?
          @status = @alive ? :suspended : :dead
          result.is_a?(ObjectObject) ? result : NilObject::NIL
        rescue FrozoneException => e
          @alive = false
          @status = :dead
          raise
        rescue ::FiberError => e
          @alive = false
          @status = :dead
          raise FrozoneException.make(:FiberError, e.message)
        ensure
          restore_and_save_globals(saved_outer, @fiber_globals)
        end
      end

      # Schedule an exception to be raised on next resume
      def schedule_raise(exception)
        @raise_exception = exception
      end

      private

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
  end
end
