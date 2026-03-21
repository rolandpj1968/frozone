class Thread
  def self.report_on_exception=(val); nil; end
  def self.report_on_exception = false
  def self.abort_on_exception=(val); nil; end
  def self.abort_on_exception = false
  @@pending              = []
  @@all                  = []
  @@main                 = nil
  @@current              = nil
  @@run_depth            = 0     # incremented while a thread block is executing
  @@last_blocked_as_yield = false # set by Thread.pass before raising Blocked

  def self.new(*args, &block)
    t = super
    # After initialize: if @block was not set, the subclass didn't call super with a block.
    unless t.instance_variable_defined?(:@block)
      @@pending.delete(t)
      @@all.delete(t)
      fail ThreadError, "must be called with a block"
    end
    t
  end

  def self.current
    @@current || (@@main ||= new_main_thread)
  end

  def self.main = (@@main ||= new_main_thread)
  def self.list = [Thread.main] + @@pending + @@all.select(&:alive?)

  def self.new_main_thread
    t = allocate
    t.__init_main
    t
  end
  private_class_method :new_main_thread

  # Thread.pass runs the next pending thread.
  # When called from inside a running thread (run_depth > 0) with nothing pending,
  # raises Thread::Blocked so loops like `loop { Thread.pass }` terminate.
  # This marks the thread as "run-yielded" so status remains 'run' (not 'sleep').
  def self.pass
    if @@pending.empty?
      if @@run_depth > 0
        @@last_blocked_as_yield = true
        raise Blocked
      end
      return nil
    end
    t = @@pending.shift
    t.__run_block
    nil
  end

  def self.__run_next_pending
    if @@pending.empty?
      if @@run_depth > 0
        @@last_blocked_as_yield = true
        raise Blocked
      end
      return nil
    end
    t = @@pending.shift
    t.__run_block
    t
  end

  # Returns true if the thread is currently in the pending queue (blocked/waiting).
  def self.__pending_include?(t) = @@pending.include?(t)

  # Thread.stop puts the current thread to sleep until woken by #run or #wakeup.
  # Uses @wakeup_count (total wakeups received) and @stop_seen (Thread.stop calls
  # seen in current replay run) to replay past the stopped positions:
  # if @stop_seen < @wakeup_count, increment @stop_seen and return (skip this stop).
  # Otherwise raise Blocked so the thread is re-queued.
  # Does NOT set @@last_blocked_as_yield — so status stays 'sleep' (not 'run').
  def self.stop
    current = Thread.current
    seen = (current.__stop_seen || 0)
    if seen < (current.__wakeup_count || 0)
      current.__stop_seen = seen + 1
      return nil
    end
    raise Blocked
  end

  # Exposed for Thread.stop replay mechanism
  def __stop_seen;    @stop_seen;    end
  def __stop_seen=(v); @stop_seen = v; end
  def __wakeup_count;    @wakeup_count;    end
  def __wakeup_count=(v); @wakeup_count = v; end

  # Status reflects execution state:
  #   'run'      — currently executing OR blocked via Thread.pass (cooperative yield)
  #   'sleep'    — new/unstarted, waiting for a resource, or Thread.stop'd
  #   'aborting' — kill called on self while executing (in ensure block)
  #   false      — completed normally or killed (no exception)
  #   nil        — completed with uncaught exception
  def status
    return 'aborting' if @aborting
    return nil        if @done && @exception
    return false      if @done
    return 'run'      if @executing || @run_yielded
    'sleep'
  end

  def alive? = !@done || @aborting
  def stop?  = !@aborting && (@done || (!@executing && !@run_yielded))

  def report_on_exception=(val); @report_on_exception = val; end
  def report_on_exception = @report_on_exception.nil? ? false : @report_on_exception

  def initialize(*args, &block)
    return unless block  # Thread.new will detect missing block and raise ThreadError
    @block               = args.empty? ? block : proc { block.call(*args) }
    @result              = nil
    @exception           = nil
    @done                = false
    @executing           = false
    @run_yielded         = false
    @aborting            = false
    @wakeup_count        = 0
    @stop_seen           = 0
    @report_on_exception = false
    @name                = nil
    @thread_vars         = {}
    @fiber_vars          = {}
    @@pending << self
    @@all << self
  end

  # Raised (and caught internally) when a thread blocks on an unavailable resource.
  # join(timeout) returns nil instead of waiting; join (no timeout) propagates as ThreadError.
  class Blocked < Exception; end

  def join(timeout = nil)
    unless timeout.nil?
      case timeout
      when Integer, Float then # ok
      when NilClass       then # ok (nil)
      else Kernel.raise TypeError, "no implicit conversion of #{timeout.class} into Float"
      end
      return self if @done
      return nil if timeout == 0.0
      __run_block(timeout_mode: true)
      return @done ? self : nil
    end
    __run_block
    self
  end

  def value
    __run_block
    Kernel.raise @exception if @exception
    @result
  end

  def kill
    @@pending.delete(self)
    @done = true
    if equal?(@@current)
      @self_killed = true
      @aborting    = true
    end
    self
  end
  alias terminate kill
  alias exit      kill

  def wakeup
    fail ThreadError, "dead thread called wakeup" if @done && !@aborting
    # Only bank wakeup count when thread is truly sleeping (Thread.stop blocked),
    # not when it's in run state (Thread.pass yielded). Mirrors MRI semantics where
    # wakeup on a running/yielded thread does not bank for future Thread.stop calls.
    @wakeup_count = (@wakeup_count || 0) + 1 unless @run_yielded || @executing
    __run_block
    self
  end

  def run
    fail ThreadError, "dead thread called wakeup" if @done && !@aborting
    @wakeup_count = (@wakeup_count || 0) + 1 unless @run_yielded || @executing
    __run_block
    self
  end

  def raise(*args)
    # Mark thread as done with an exception (no actual raise in cooperative model)
    @done = true
    exc = args.empty? ? RuntimeError.new : (args[0].is_a?(Exception) ? args[0] : args[0].new(*args[1..]))
    @exception = exc
    self
  end

  def backtrace           = nil
  def backtrace_locations = nil
  def priority            = 0
  def priority=(v)        = 0
  def native_thread_id    = nil
  def name                = @name
  def name=(v)            = (@name = v.nil? ? nil : v.to_str)
  def group               = nil
  def pending_interrupt?(exc = nil) = false
  def add_trace_func(f)   = f
  def set_trace_func(f)   = f

  def inspect
    id_str = ('0x%016x' % (__id__ * 2))
    status_str = case status
                 when 'run'      then 'run'
                 when 'sleep'    then 'sleep'
                 when 'aborting' then 'aborting'
                 when false      then 'dead'
                 when nil        then 'dead'
                 else                 'dead'
                 end
    "#<Thread:#{id_str} #{status_str}>"
  end
  alias to_s inspect

  def __init_main
    @block               = nil
    @result              = nil
    @exception           = nil
    @done                = false
    @executing           = false
    @run_yielded         = false
    @aborting            = false
    @wakeup_count        = 0
    @stop_seen           = 0
    @report_on_exception = false
    @name                = nil
    @thread_vars         = {}
    @fiber_vars          = {}
  end

  def __run_block(timeout_mode: false)
    return if @done && !@aborting
    return if @executing
    @@pending.delete(self)
    @executing    = true
    @run_yielded  = false
    @stop_seen    = 0          # reset replay counter at start of each run
    @self_killed  = false
    prev          = @@current
    @@current     = self
    @@run_depth  += 1
    Intrinsics.thread_save_reset_locals(self)
    begin
      ret = Intrinsics.thread_run_block(@block)
      @done      = true
      @aborting  = false
      @result    = @self_killed ? nil : ret
    rescue Blocked
      # Thread blocked; record whether this was a cooperative yield (Thread.pass)
      # or a resource block (mutex, queue, Thread.stop), then re-queue.
      @run_yielded = @@last_blocked_as_yield
      @@last_blocked_as_yield = false
      @@pending << self
    rescue => e
      if timeout_mode && e.is_a?(ThreadError) && e.message.start_with?("deadlock")
        # Cooperative deadlock during timeout join: reset for retry
        @run_yielded = false
        @@pending << self
      else
        @done      = true
        @aborting  = false
        @exception = e
      end
    ensure
      @executing  = false
      @@run_depth -= 1
      @@current   = prev
      Intrinsics.thread_restore_locals(self)
    end
  end

  # Thread-local variables (not fiber-local)
  def thread_variable_set(key, value)
    @thread_vars ||= {}
    @thread_vars[key.to_sym] = value
  end

  def thread_variable_get(key)
    @thread_vars ||= {}
    @thread_vars[key.to_sym]
  end

  def thread_variable?(key)
    @thread_vars ||= {}
    @thread_vars.key?(key.to_sym)
  end

  def thread_variables
    @thread_vars ||= {}
    @thread_vars.keys.map { |k| k.to_s.to_sym }
  end

  # Fiber-local variables (Thread#[] / Thread#[]=)
  def [](key)
    @fiber_vars ||= {}
    @fiber_vars[key.to_sym]
  end

  def []=(key, value)
    @fiber_vars ||= {}
    @fiber_vars[key.to_sym] = value
  end

  def key?(key)
    @fiber_vars ||= {}
    @fiber_vars.key?(key.to_sym)
  end

  def keys
    @fiber_vars ||= {}
    @fiber_vars.keys.map { |k| k.to_s.to_sym }
  end

  Mutex = ::Mutex

end

class ConditionVariable
  def initialize
    @waiters = 0
  end
  # In single-threaded model: wait runs pending threads until signalled.
  # Since we're cooperative, just run pending threads and return.
  def signal    = self
  def broadcast = self

  def wait(mutex, timeout = nil)
    mutex.unlock
    # Run pending threads to allow broadcast/signal to be called
    Thread.__run_next_pending
    mutex.lock
    self
  end
end

# Queue: thread-safe FIFO queue with blocking pop (cooperative single-threaded)
class Queue
  def empty?      = @data.empty?
  def size        = @data.size
  alias length size
  def clear       = (@data.clear; self)
  def num_waiting = @waiters.size
  def closed?     = @closed

  def initialize
    @data      = []
    @closed    = false
    @waiters   = Set.new
    @deadlines = {}  # thread.object_id => Float (absolute Time deadline)
  end

  def close
    @closed = true
    self
  end

  def push(obj)
    raise ClosedQueueError, "queue closed" if @closed
    @data.push(obj)
    self
  end
  alias enq push
  alias << push

  def pop(non_block = false, timeout: nil)
    if @data.empty?
      return nil if @closed
      raise ThreadError, "queue empty" if non_block
      return nil if !timeout.nil? && timeout == 0
      # Cooperative blocking: run pending threads until data arrives.
      # @waiters uses Set for idempotency across Blocked re-runs.
      # @deadlines persists the deadline across re-runs (||= won't reset it).
      current = Thread.current
      tid = current.object_id
      @deadlines[tid] ||= Time.now.to_f + timeout if !timeout.nil?
      @waiters.add(current)
      blocked = false
      begin
        loop do
          t = Thread.__run_next_pending
          break unless @data.empty?
          return nil if @closed
          return nil if @deadlines[tid] && Time.now.to_f >= @deadlines[tid]
          # No pending thread, or the thread we ran immediately blocked again:
          # neither case can unblock us, so we must suspend too.
          (blocked = true; raise Thread::Blocked) if t.nil? || Thread.__pending_include?(t)
        end
      rescue Thread::Blocked
        raise  # re-raise, keeping thread in @waiters and @deadlines
      ensure
        unless blocked
          @waiters.delete(current)
          @deadlines.delete(tid)
        end
      end
    else
      # Data available without entering blocking section: clean up any stale deadline
      @deadlines.delete(Thread.current.object_id)
    end
    @data.shift
  end
  alias deq   pop
  alias shift pop
end

class SizedQueue < Queue
  def max = @max
  def num_waiting = @waiters.size + @push_waiters.size

  def initialize(max)
    super()
    @max          = max
    @push_waiters = Set.new
    @push_deadlines = {}
  end

  def max=(v); @max = v; end

  def push(obj, non_block = false, timeout: nil)
    raise ClosedQueueError, "queue closed" if @closed
    raise ArgumentError, "can't set a timeout if non_block is enabled" if non_block && !timeout.nil?
    if @data.size >= @max
      raise ThreadError, "queue full" if non_block
      return nil if !timeout.nil? && timeout == 0
      current = Thread.current
      tid = current.object_id
      @push_deadlines[tid] ||= Time.now.to_f + timeout if !timeout.nil?
      @push_waiters.add(current)
      blocked = false
      begin
        loop do
          t = Thread.__run_next_pending
          break if @data.size < @max
          raise ClosedQueueError, "queue closed" if @closed
          return nil if @push_deadlines[tid] && Time.now.to_f >= @push_deadlines[tid]
          (blocked = true; raise Thread::Blocked) if t.nil? || Thread.__pending_include?(t)
        end
      rescue Thread::Blocked
        raise
      ensure
        unless blocked
          @push_waiters.delete(current)
          @push_deadlines.delete(tid)
        end
      end
    end
    raise ClosedQueueError, "queue closed" if @closed
    @data.push(obj)
    self
  end
  alias enq push
  alias << push
end
