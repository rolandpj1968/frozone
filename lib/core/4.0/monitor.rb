# Pure-Ruby Monitor implementation for Frozone.
# Monitor is a reentrant mutex — the same thread may enter multiple times.
# MonitorMixin is copied from Ruby stdlib monitor.rb (already pure Ruby there).

class Monitor
  def mon_locked? = @mutex.locked?
  def mon_owned?  = @owner.equal?(Thread.current)

  def initialize
    @mutex = Mutex.new
    @owner = nil
    @count = 0
  end

  def enter
    current = Thread.current
    if @owner.equal?(current)
      @count += 1
    else
      @mutex.lock
      @owner = current
      @count = 1
    end
  end

  def exit
    mon_check_owner
    @count -= 1
    if @count == 0
      @owner = nil
      @mutex.unlock
    end
  end

  def try_enter
    current = Thread.current
    if @owner.equal?(current)
      @count += 1
      return true
    end
    if @mutex.try_lock
      @owner = current
      @count = 1
      return true
    end
    false
  end

  def synchronize
    enter
    begin
      yield
    ensure
      exit
    end
  end

  def mon_check_owner
    raise ThreadError, "current thread not owner" unless mon_owned?
  end

  def wait_for_cond(cond, timeout)
    current = Thread.current
    count   = @count
    @count  = 0
    @owner  = nil
    @mutex.unlock
    begin
      cond.wait(@mutex, *[timeout].compact)
    ensure
      @mutex.lock
      @owner = current
      @count = count
    end
  end

  alias try_mon_enter try_enter
  alias mon_try_enter try_enter
  alias mon_enter     enter
  alias mon_exit      exit
  alias mon_synchronize synchronize

  def new_cond
    MonitorMixin::ConditionVariable.new(self)
  end
end

module MonitorMixin
  class ConditionVariable
    def wait(timeout = nil)
      @monitor.mon_check_owner
      @monitor.wait_for_cond(@cond, timeout)
    end

    def wait_while
      while yield
        wait
      end
    end

    def wait_until
      until yield
        wait
      end
    end

    def signal
      @monitor.mon_check_owner
      @cond.signal
    end

    def broadcast
      @monitor.mon_check_owner
      @cond.broadcast
    end

    private

    def initialize(monitor)
      @monitor = monitor
      @cond    = ConditionVariable.new
    end
  end

  def self.extend_object(obj)
    super(obj)
    obj.__send__(:mon_initialize)
  end

  def mon_try_enter  = @mon_data.try_enter
  alias try_mon_enter mon_try_enter

  def mon_enter      = @mon_data.enter
  def mon_exit       = (mon_check_owner; @mon_data.exit)
  def mon_locked?    = @mon_data.mon_locked?
  def mon_owned?     = @mon_data.mon_owned?

  def mon_synchronize(&b)
    @mon_data.synchronize(&b)
  end
  alias synchronize mon_synchronize

  def new_cond
    mon_initialize unless defined?(@mon_data)
    ConditionVariable.new(@mon_data)
  end

  def mon_check_owner
    @mon_data.mon_check_owner
  end

  private

  def initialize(...)
    super
    mon_initialize
  end

  def mon_initialize
    if defined?(@mon_data)
      return if defined?(@mon_initialized_by_new_cond)
      raise ThreadError, "already initialized" if @mon_data_owner_object_id == object_id
    end
    @mon_data = ::Monitor.new
    @mon_data_owner_object_id = object_id
  end
end
