class Mutex
  def lock = (@locked = true; self)
  def unlock = (@locked = false; self)
  def locked? = @locked
  def owned? = @locked
  def try_lock = !@locked && (@locked = true)

  def initialize
    @locked = false
  end

  def synchronize(&block)
    lock
    begin
      block.call
    ensure
      unlock
    end
  end
end
