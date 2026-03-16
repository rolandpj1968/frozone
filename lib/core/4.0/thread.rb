class Thread
  def self.report_on_exception=(val); nil; end
  def self.report_on_exception = false
  def self.pass; nil; end  # no-op in single-threaded VM

  # Single-threaded: defers block until join/value to avoid spin-lock hangs.
  # thread_run_block invokes with thread_boundary:true so `break` raises
  # LocalJumpError rather than propagating out.
  def initialize(&block)
    @block     = block
    @result    = nil
    @exception = nil
    @done      = false
  end

  def join(timeout = nil)
    _run_block
    self
  end

  def value
    _run_block
    raise @exception if @exception
    @result
  end

  def status  = @done ? false : 'sleep'
  def alive?  = !@done

  private

  def _run_block
    return if @done
    @done = true
    Intrinsics.thread_save_reset_locals(self)
    begin
      @result = Intrinsics.thread_run_block(@block)
    rescue => e
      @exception = e
    ensure
      Intrinsics.thread_restore_locals(self)
    end
  end

  class Mutex
    def initialize
      @locked = false
    end

    def lock          = (@locked = true; self)
    def unlock        = (@locked = false; self)
    def locked?       = @locked
    def try_lock      = !@locked && (@locked = true)

    def synchronize(&block)
      lock
      begin
        block.call
      ensure
        unlock
      end
    end
  end
end
