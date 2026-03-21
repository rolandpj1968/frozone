class Mutex
  def locked? = @locked
  def owned?  = @owner.equal?(Thread.current)

  def initialize
    @locked = false
    @owner  = nil
  end

  def lock
    if @locked
      raise ThreadError, "deadlock; recursive locking" if @owner.equal?(Thread.current)
      raise Thread::Blocked
    end
    @locked = true
    @owner  = Thread.current
    Thread.current.__add_owned_mutex(self)
    self
  end

  def unlock
    owner = @owner
    @locked = false
    @owner  = nil
    owner.__remove_owned_mutex(self) if owner
    self
  end

  def __force_unlock
    @locked = false
    @owner  = nil
    self
  end

  def try_lock
    return false if @locked
    @locked = true
    @owner  = Thread.current
    true
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
    unlock
    timeout ? Kernel.sleep(timeout) : Thread.pass
    lock
    self
  end
end
