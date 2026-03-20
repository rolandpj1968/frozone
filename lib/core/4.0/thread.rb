class Thread
  def self.report_on_exception=(val); nil; end
  def self.report_on_exception = false
  def self.abort_on_exception=(val); nil; end
  def self.abort_on_exception = false
  @@pending = []
  @@all     = []
  @@main    = nil
  @@current = nil

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

  # Thread.pass runs the next pending thread so that spin-loops like
  # `Thread.pass until flag` work in single-threaded VM.
  def self.pass
    t = @@pending.shift
    t.__run_block if t
    nil
  end

  def self.__run_next_pending
    t = @@pending.shift
    t.__run_block if t
    t
  end

  # Single-threaded: pending threads are "sleeping", done threads are "dead".
  def status = @done ? false : 'sleep'
  def alive? = !@done
  def stop?  = true   # always sleeping or dead in cooperative model

  def report_on_exception=(val); @report_on_exception = val; end
  def report_on_exception = @report_on_exception.nil? ? false : @report_on_exception

  def initialize(&block)
    @block              = block
    @result             = nil
    @exception          = nil
    @done               = false
    @report_on_exception = false
    @name               = nil
    @thread_vars        = {}
    @fiber_vars         = {}
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
    @self_killed = true if equal?(@@current)
    self
  end
  alias terminate kill
  alias exit      kill

  def wakeup
    __run_block
    self
  end

  def run
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

  def backtrace         = nil
  def backtrace_locations = nil
  def priority          = 0
  def priority=(v)      = 0
  def native_thread_id  = nil
  def name              = @name
  def name=(v)          = (@name = v.nil? ? nil : v.to_str)
  def group             = nil
  def pending_interrupt?(exc = nil) = false
  def add_trace_func(f) = f
  def set_trace_func(f) = f

  def inspect
    id_str = ('0x%016x' % (__id__ * 2))
    status_str = @done ? 'dead' : 'sleep'
    "#<Thread:#{id_str} #{status_str}>"
  end
  alias to_s inspect

  def __init_main
    @block              = nil
    @result             = nil
    @exception          = nil
    @done               = false
    @report_on_exception = false
    @name               = nil
    @thread_vars        = {}
    @fiber_vars         = {}
  end

  def __run_block(timeout_mode: false)
    return if @done
    @@pending.delete(self)
    @done = true
    @self_killed = false
    prev = @@current
    @@current = self
    Intrinsics.thread_save_reset_locals(self)
    begin
      ret = Intrinsics.thread_run_block(@block)
      @result = @self_killed ? nil : ret
    rescue Blocked
      # Thread blocked on unavailable resource; reset to pending for retry
      @done = false
      @@pending << self
    rescue => e
      if timeout_mode && e.is_a?(ThreadError) && e.message.start_with?("deadlock")
        # Cooperative deadlock during timeout join: reset for retry
        @done = false
        @@pending << self
      else
        @exception = e
      end
    ensure
      @@current = prev
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
  def num_waiting = 0
  def closed?     = @closed

  def initialize
    @data   = []
    @closed = false
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

  def pop(non_block = false)
    if @data.empty?
      raise ClosedQueueError, "queue closed" if @closed
      if non_block
        raise ThreadError, "queue empty"
      end
      # In cooperative single-threaded model: run pending threads until data arrives
      loop do
        t = Thread.__run_next_pending
        break unless @data.empty?
        raise Thread::Blocked if t.nil?  # no thread can unblock us; suspend
      end
    end
    @data.shift
  end
  alias deq   pop
  alias shift pop
end

class SizedQueue < Queue
  def max = @max

  def initialize(max)
    super()
    @max = max
  end
  def max=(v); @max = v; end
end
