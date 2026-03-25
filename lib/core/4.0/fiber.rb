class Fiber
  def self.yield(*args)  = Intrinsics.fiber_yield(self, args)
  def self.current       = Intrinsics.fiber_current(self)
  def self.blocking?     = Intrinsics.fiber_class_blocking_q(self)
  def self.[](key)       = Intrinsics.fiber_storage_get(self, key)
  def self.[]=(key, val); Intrinsics.fiber_storage_set(self, key, val); end
  def self.scheduler     = @__scheduler__
  def resume(*args)      = Intrinsics.fiber_resume(self, args)
  def transfer(*args)    = Intrinsics.fiber_transfer(self, args)
  def alive?             = Intrinsics.fiber_alive(self)
  def blocking?          = Intrinsics.fiber_blocking_q(self)
  def inspect            = Intrinsics.fiber_inspect(self)
  def to_s               = inspect
  def kill               = Intrinsics.fiber_kill(self)
  def storage            = Intrinsics.fiber_storage_hash(self)
  def storage=(val); Intrinsics.fiber_storage_hash_set(self, val); end

  def self.new(blocking: false, storage: :__unset__, &block)
    raise ArgumentError, "tried to create Fiber object without a block" unless block
    Intrinsics.fiber_new(self, block, blocking, storage)
  end

  def self.blocking(blocking = true)
    current = Fiber.current
    was_blocking = current.blocking?
    Intrinsics.fiber_set_blocking(current, blocking)
    begin
      yield current
    ensure
      Intrinsics.fiber_set_blocking(current, was_blocking)
    end
  end

  def self.set_scheduler(scheduler)
    if scheduler.nil?
      @__scheduler__ = nil
      return nil
    end
    %i[block unblock kernel_sleep io_wait].each do |m|
      raise ArgumentError, "Scheduler must implement ##{m}" unless scheduler.respond_to?(m)
    end
    @__scheduler__ = scheduler
  end

  def raise(msg = :__raise_no_arg__, message = nil, backtrace = nil, cause: :__raise_no_cause__, **extra_kwargs)
    # Extra kwargs (other than cause:) are passed as part of the message hash for compatibility
    if extra_kwargs.empty?
      Intrinsics.fiber_raise(self, msg, message, backtrace, cause)
    else
      msg_hash = message.nil? ? extra_kwargs : extra_kwargs
      Intrinsics.fiber_raise(self, msg, msg_hash, backtrace, cause)
    end
  end
end
