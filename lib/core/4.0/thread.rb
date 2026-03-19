class Thread
  def self.report_on_exception=(val); nil; end
  def self.report_on_exception = false
  @@pending = []
  @@main = nil

  def self.current
    @@main ||= new_main_thread
  end

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
  # Single-threaded: defers block until Thread.pass/join/value.
  # thread_run_block invokes with thread_boundary:true so `break` raises
  # LocalJumpError rather than propagating out.
  def status = @done ? false : 'sleep'
  def alive? = !@done

  def initialize(&block)
    @block       = block
    @result      = nil
    @exception   = nil
    @done        = false
    @thread_vars = {}
    @fiber_vars  = {}
    @@pending << self
  end

  def join(timeout = nil)
    __run_block
    self
  end

  def value
    __run_block
    raise @exception if @exception
    @result
  end

  def __init_main
    @block     = nil
    @result    = nil
    @exception = nil
    @done      = false
    @thread_vars = {}
    @fiber_vars  = {}
  end

  def __run_block
    return if @done
    @@pending.delete(self)
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
  class Mutex
    def lock = (@locked = true; self)
    def unlock = (@locked = false; self)
    def locked? = @locked
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

end

class ConditionVariable
  def initialize
    @waiters = 0
  end
  # In single-threaded model: wait runs pending threads until signalled.
  # Since we're cooperative, just run pending threads and return.
  def signal = self
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
  def empty? = @data.empty?
  def size = @data.size
  alias length size
  def clear = (@data.clear; self)
  def num_waiting = 0

  def initialize
    @data = []
  end

  def push(obj)
    @data.push(obj)
    self
  end
  alias enq push
  alias << push

  def pop(non_block = false)
    if @data.empty?
      if non_block
        raise ThreadError, "queue empty"
      end
      # In cooperative single-threaded model: run pending threads until data arrives
      loop do
        Thread.__run_next_pending
        break unless @data.empty?
      end
    end
    @data.shift
  end
  alias deq pop
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
