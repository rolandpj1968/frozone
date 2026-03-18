class Fiber
  def self.new(blocking: false, storage: :__unset__, &block)
    raise ArgumentError, "tried to create Fiber object without a block" unless block
    Intrinsics.fiber_new(self, block, blocking, storage)
  end

  def self.yield(*args)   = Intrinsics.fiber_yield(self, args)
  def self.current        = Intrinsics.fiber_current(self)
  def self.blocking?      = Intrinsics.fiber_class_blocking_q(self)

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

  def self.[](key)        = Intrinsics.fiber_storage_get(self, key)
  def self.[]=(key, val)  = Intrinsics.fiber_storage_set(self, key, val)

  def resume(*args)       = Intrinsics.fiber_resume(self, args)
  def transfer(*args)     = Intrinsics.fiber_transfer(self, args)
  def alive?              = Intrinsics.fiber_alive(self)
  def blocking?           = Intrinsics.fiber_blocking_q(self)
  def inspect             = Intrinsics.fiber_inspect(self)
  def to_s                = inspect

  def raise(*args)        = Intrinsics.fiber_raise(self, args)
  def kill                = Intrinsics.fiber_kill(self)

  def storage             = Intrinsics.fiber_storage_hash(self)
  def storage=(val)       = Intrinsics.fiber_storage_hash_set(self, val)
end
