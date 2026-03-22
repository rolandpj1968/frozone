class Mutex
  def locked? = @locked

  def owned?
    return false unless @locked
    # Ownership is per fiber-within-thread: check both current thread and
    # current Frozone fiber (Fiber.current's fiber object or nil for main fiber).
    @owner.equal?(Thread.current) && @owner_fiber.equal?(Fiber.current)
  end

  def initialize
    @locked      = false
    @owner       = nil
    @owner_fiber = nil
  end

  def lock
    if @locked
      raise ThreadError, "deadlock; recursive locking" if owned?
      raise Thread::Blocked
    end
    @locked      = true
    @owner       = Thread.current
    @owner_fiber = Fiber.current
    Thread.current.__add_owned_mutex(self)
    self
  end

  def unlock
    raise ThreadError, "Attempt to unlock a mutex which is not locked" unless @locked
    raise ThreadError, "Attempt to unlock a mutex which is locked by another thread/fiber" unless owned?
    owner = @owner
    @locked      = false
    @owner       = nil
    @owner_fiber = nil
    owner.__remove_owned_mutex(self)
    self
  end

  def __force_unlock
    @locked      = false
    @owner       = nil
    @owner_fiber = nil
    self
  end

  def try_lock
    return false if @locked
    @locked      = true
    @owner       = Thread.current
    @owner_fiber = Fiber.current
    Thread.current.__add_owned_mutex(self)
    self
  end

  def synchronize(&block)
    lock
    begin
      block.call
    ensure
      unlock
    end
  end

  def sleep(timeout = nil)
    raise ThreadError, "can't sleep with unlocked mutex" unless owned?
    if timeout
      raise ArgumentError, "time interval must be positive" if timeout < 0
      unlock
      begin
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        Kernel.sleep(timeout)
        (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round
      ensure
        lock
      end
    else
      unlock
      begin
        Thread.stop
        0
      ensure
        lock
      end
    end
  end
end
