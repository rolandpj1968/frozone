class Mutex
  def lock = (@locked = true; self)
  def unlock = (@locked = false; self)
  def locked? = @locked
  def owned? = @locked   # single-threaded: if locked, owner is always current
  def try_lock = !@locked && (@locked = true)

  def initialize
    @locked = false
  end

  def synchronize(&block)
    Kernel.raise ThreadError, "deadlock; recursive locking" if @locked
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
