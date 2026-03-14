module Frozone
  module Vm
    # VM Fiber object — wraps a Ruby Fiber for coroutine switching.
    # Each Frozone Fiber runs its block on a native Ruby Fiber, giving true
    # coroutine semantics. $! and $@ are fiber-local (saved/restored at each
    # resume/yield boundary).
    class FiberObject < ObjectObject
      FIBER_LOCAL_GLOBALS = %i[$! $@].freeze

      def initialize(block_obj)
        super(Core.fiber_class || Core::OBJECT_CLASS)
        @block_obj = block_obj
        # Per-fiber snapshots of $! and $@ (start as nil)
        @fiber_globals = { :"$!" => NilObject::NIL, :"$@" => NilObject::NIL }
        @ruby_fiber = nil
        @alive = true
      end

      def alive? = @alive

      def resume(outer_context, args)
        unless @alive
          raise FrozoneException.make(:FiberError, "dead fiber called")
        end

        # Swap outer $!/$@ with this fiber's saved values
        saved_outer = save_and_swap_globals(@fiber_globals)

        if @ruby_fiber.nil?
          bo = @block_obj
          fg = @fiber_globals
          fc = Context.new
          @ruby_fiber = ::Fiber.new do
            ::Fiber[:frozone_fiber] = ::Fiber.current
            ::Fiber[:context] = fc
            begin
              bo.invoke(fc, args)
            end
          end
        end

        begin
          result = @ruby_fiber.resume
          @alive = @ruby_fiber.alive?
          result.is_a?(ObjectObject) ? result : NilObject::NIL
        rescue FrozoneException
          @alive = false
          raise
        rescue ::FiberError => e
          @alive = false
          raise FrozoneException.make(:FiberError, e.message)
        ensure
          restore_and_save_globals(saved_outer, @fiber_globals)
        end
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
