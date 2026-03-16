class Fiber
  def self.new(&block)    = Intrinsics.fiber_new(self, block)
  def self.yield(*args)   = Intrinsics.fiber_yield(self, args)
  def self.current        = Intrinsics.fiber_current(self)
  def self.[](key)        = Intrinsics.fiber_storage_get(self, key)
  def self.[]=(key, val)  = Intrinsics.fiber_storage_set(self, key, val)

  def resume(*args)       = Intrinsics.fiber_resume(self, args)
  def alive?              = Intrinsics.fiber_alive(self)
end
