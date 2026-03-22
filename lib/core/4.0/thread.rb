class Thread
  @@report_on_exception = true
  def self.report_on_exception=(val); @@report_on_exception = val; end
  def self.report_on_exception = @@report_on_exception
  def self.abort_on_exception=(val); nil; end
  def self.abort_on_exception = false
  def self.handle_interrupt(_config, &block); block.call; end
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

  def self.start(*args, &block)
    Kernel.raise ArgumentError, "tried to create Thread object without a block" unless block
    t = allocate
    t.__start_init(block, args)
    t
  end
  class << self
    alias fork start
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
  # Thread.pass cooperatively yields the current thread.
  # From inside a running thread (run_depth > 0): always suspends (raises Blocked),
  # never runs other pending threads. This prevents nested thread loops from
  # starving the main scheduler.
  # From the main thread (run_depth == 0): runs the next pending thread.
  def self.pass
    if @@run_depth > 0
      @@last_blocked_as_yield = true
      # If the current thread has a pending raise, inject it now instead of blocking.
      current = Thread.current
      exc = current.__raise_exception
      if exc
        cause = current.__raise_cause
        raise_bt = current.__raise_backtrace
        current.__raise_exception = nil
        current.__raise_cause = nil
        current.__raise_backtrace = nil
        raise exc, nil, raise_bt, cause: cause
      end
      raise Blocked
    end
    return nil if @@pending.empty?
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

  # Returns number of threads in the pending queue.
  def self.__pending_size = @@pending.size

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
  def __raise_exception;    @raise_exception;    end
  def __raise_exception=(v); @raise_exception = v; end
  def __raise_cause;    @raise_cause;    end
  def __raise_cause=(v); @raise_cause = v; end
  def __raise_backtrace;    @raise_backtrace;    end
  def __raise_backtrace=(v); @raise_backtrace = v; end

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
  def report_on_exception = @report_on_exception.nil? ? Thread.report_on_exception : @report_on_exception

  def __start_init(block, args)
    sl = block.source_location
    @source_location_str = sl ? "#{sl[0]}:#{sl[1]}" : nil
    @block               = args.empty? ? block : proc { block.call(*args) }
    @result              = nil
    @exception           = nil
    @done                = false
    @executing           = false
    @run_yielded         = false
    @aborting            = false
    @wakeup_count        = 0
    @stop_seen           = 0
    @raise_exception     = nil
    @raise_cause         = nil
    @raise_backtrace     = nil
    @report_on_exception = nil
    @name                = nil
    @thread_vars         = {}
    @fiber_vars          = {}
    @owned_mutexes       = []
    @group               = ThreadGroup::Default
    ThreadGroup::Default.__add_thread(self)
    @@pending << self
    @@all << self
  end

  def initialize(*args, &block)
    return unless block  # Thread.new will detect missing block and raise ThreadError
    __start_init(block, args)
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
    Kernel.raise @exception if @exception
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

  def raise(*args, **kwargs)
    return nil if @done && !@aborting

    # Extract cause: keyword; remaining kwargs become the message hash
    cause_given = kwargs.key?(:cause)
    cause = kwargs.delete(:cause)
    msg_hash = kwargs.empty? ? nil : kwargs

    # Validate explicit cause type
    if cause_given && !cause.nil? && !cause.is_a?(Exception)
      Kernel.raise TypeError, "exception object expected"
    end

    # ArgumentError when only cause: is given with no positional args and no other kwargs
    if args.empty? && msg_hash.nil? && cause_given
      Kernel.raise ArgumentError, "only cause is given with no arguments"
    end

    exc = if args.empty? && msg_hash.nil?
      RuntimeError.new("")
    elsif args[0].is_a?(String) && args.size == 1 && msg_hash.nil?
      RuntimeError.new(args[0])
    elsif args[0].is_a?(String)
      # String with extra args (positional or keyword) is always TypeError
      Kernel.raise TypeError, "exception class/object expected"
    elsif args[0].is_a?(Exception) && args.size <= 1 && msg_hash.nil?
      args[0]
    elsif args.size >= 1 && args[0].respond_to?(:exception)
      # Pass message (args[1] or msg_hash) but NOT backtrace (args[2]) to exception
      message = args.size >= 2 ? args[1] : msg_hash
      result = message.nil? ? args[0].exception : args[0].exception(message)
      unless result.is_a?(Exception)
        Kernel.raise TypeError, "exception object expected"
      end
      result
    else
      Kernel.raise TypeError, "exception class/object expected"
    end

    # Backtrace override: args[2] if present (array of strings or Location objects).
    backtrace = args.size >= 3 ? args[2] : nil

    # Raising on the current thread: inject immediately into the live call stack.
    if equal?(Thread.current)
      if cause_given
        Kernel.raise exc, nil, backtrace, cause: cause
      else
        Kernel.raise exc, nil, backtrace
      end
    end
    # Inject exception into a sleeping/running thread via replay mechanism.
    # Thread.stop and Thread.pass both check @raise_exception before blocking.
    # Store explicit cause (nil means "no auto-chain"; :__not_given means use default).
    @raise_exception = exc
    @raise_cause = cause_given ? cause : nil
    @raise_backtrace = backtrace
    __run_block
    self
  end

  def backtrace(start_or_range = 0, length = nil)
    return nil if @done && !@aborting
    return [] unless equal?(Thread.current)
    full = caller(1)
    if start_or_range.is_a?(Range)
      full[start_or_range]
    else
      start = start_or_range
      return nil if start > full.size
      length.nil? ? full[start..] : full[start, length]
    end
  end

  def backtrace_locations(start_or_range = 0, length = nil)
    return nil if @done && !@aborting
    return [] unless equal?(Thread.current)
    full = caller_locations(1)
    if start_or_range.is_a?(Range)
      full[start_or_range]
    else
      start = start_or_range
      return nil if start > full.size
      length.nil? ? full[start..] : full[start, length]
    end
  end
  def priority = (@priority || 0)

  def priority=(v)
    unless v.is_a?(Integer)
      v = v.to_int if v.respond_to?(:to_int)
      Kernel.raise TypeError, "can't convert #{v.class} into Integer" unless v.is_a?(Integer)
    end
    @priority = v.clamp(-3, 3)
    v
  end
  def native_thread_id = alive? ? object_id : nil
  def name                = @name
  def name=(v)            = (@name = v.nil? ? nil : v.to_str)
  def group               = @group
  def __set_group(g)      = (@group = g)
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
    loc = @source_location_str ? " #{@source_location_str}" : ''
    "#<Thread:#{id_str}#{loc} #{status_str}>".b
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
    @raise_exception     = nil
    @raise_cause         = nil
    @raise_backtrace     = nil
    @report_on_exception = nil  # nil means inherit from Thread.report_on_exception
    @name                = nil
    @thread_vars         = {}
    @fiber_vars          = {}
    @owned_mutexes       = []
    @source_location_str = nil
    @group               = nil  # set to ThreadGroup::Default after ThreadGroup is defined
  end

  def __add_owned_mutex(m)
    @owned_mutexes ||= []
    @owned_mutexes << m unless @owned_mutexes.include?(m)
  end

  def __remove_owned_mutex(m)
    @owned_mutexes ||= []
    @owned_mutexes.delete(m)
  end

  def __run_block(timeout_mode: false)
    return if @done && !@aborting
    return if frozen?
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
      unless frozen?
        @done     = true
        @aborting = false
        @result   = @self_killed ? nil : ret
      end
    rescue Blocked
      # Thread blocked; record whether this was a cooperative yield (Thread.pass)
      # or a resource block (mutex, queue, Thread.stop), then re-queue.
      unless frozen?
        @run_yielded = @@last_blocked_as_yield
        @@last_blocked_as_yield = false
        @@pending << self
      end
    rescue => e
      if !frozen? && timeout_mode && e.is_a?(ThreadError) && e.message.start_with?("deadlock")
        # Cooperative deadlock during timeout join: reset for retry
        @run_yielded = false
        @@pending << self
      elsif !frozen?
        @done      = true
        @aborting  = false
        @exception = e
        if report_on_exception
          begin
            $stderr.puts "#{inspect} terminated with exception (report_on_exception is true):"
            $stderr.puts "#{e.message} (#{e.class})"
          rescue
            nil
          end
        end
      end
    ensure
      unless frozen?
        if @done
          # Release all mutexes held by this thread (MRI releases them on thread exit)
          (@owned_mutexes || []).each { |m| m.__force_unlock }
          @owned_mutexes = []
        end
        @executing = false
      end
      @@run_depth -= 1
      @@current   = prev
      Intrinsics.thread_restore_locals(self)
    end
  end

  # Coerce a key to Symbol; raise TypeError for invalid types.
  # Accepts: Symbol (as-is), String (#to_sym), or object with #to_str.
  # Uses Kernel.raise to bypass Thread#raise (which swallows errors on done threads).
  def __coerce_var_key(key)
    return key if key.is_a?(Symbol)
    if key.is_a?(String)
      return key.to_sym
    end
    if key.respond_to?(:to_str)
      str = key.to_str
      Kernel.raise TypeError, "can't convert #{key.class} into String" unless str.is_a?(String)
      return str.to_sym
    end
    Kernel.raise TypeError, "#{key.inspect} is not a symbol nor a string"
  end
  private :__coerce_var_key

  # Thread-local variables (not fiber-local)
  def thread_variable_set(key, value)
    Kernel.raise FrozenError, "can't modify frozen thread locals" if frozen?
    k = __coerce_var_key(key)
    @thread_vars ||= {}
    if value.nil?
      @thread_vars.delete(k)
    else
      @thread_vars[k] = value
    end
    value
  end

  def thread_variable_get(key)
    k = __coerce_var_key(key)
    (@thread_vars || {})[k]
  end

  def thread_variable?(key)
    k = __coerce_var_key(key)
    (@thread_vars || {}).key?(k)
  end

  def thread_variables
    (@thread_vars || {}).keys
  end

  # Fiber-local variables (Thread#[] / Thread#[]=)
  def [](key)
    k = __coerce_var_key(key)
    (@fiber_vars || {})[k]
  end

  def []=(key, value)
    Kernel.raise FrozenError, "can't modify frozen thread locals" if frozen?
    k = __coerce_var_key(key)
    @fiber_vars ||= {}
    @fiber_vars[k] = value
  end

  def key?(key)
    k = __coerce_var_key(key)
    (@fiber_vars || {}).key?(k)
  end

  def keys
    (@fiber_vars || {}).keys
  end

  def fetch(key, *rest, &block)
    Kernel.raise ArgumentError, "wrong number of arguments (given #{1 + rest.size}, expected 1..2)" if rest.size > 1
    if block && rest.size == 1
      warn "warning: block supersedes default value argument"
    end
    k = __coerce_var_key(key)
    vars = @fiber_vars || {}
    if vars.key?(k)
      vars[k]
    elsif block
      block.call(key)
    elsif rest.size == 1
      rest[0]
    else
      Kernel.raise KeyError, "key not found: #{key.inspect}"
    end
  end

  Mutex = ::Mutex

end

class ThreadGroup
  def initialize
    @threads  = []
    @enclosed = false
  end

  def list
    @threads.select(&:alive?)
  end

  def enclose
    @enclosed = true
    self
  end

  def enclosed? = @enclosed

  def add(thread)
    raise ThreadError, "can't move from the enclosed thread group" if thread.group&.enclosed?
    raise ThreadError, "can't move to the enclosed thread group" if @enclosed
    thread.group.__remove_thread(thread) if thread.group
    thread.__set_group(self)
    @threads << thread unless @threads.include?(thread)
    self
  end

  def __add_thread(thread)
    @threads << thread unless @threads.include?(thread)
  end

  def __remove_thread(thread)
    @threads.delete(thread)
  end

  Default = new
end

# Set main thread group after ThreadGroup is defined
Thread.main.__set_group(ThreadGroup::Default)
ThreadGroup::Default.__add_thread(Thread.main)

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
          # No pending thread available, or the thread we ran immediately re-blocked
          # AND there are no other pending threads that might push data: suspend.
          (blocked = true; raise Thread::Blocked) if t.nil? || (Thread.__pending_include?(t) && Thread.__pending_size <= 1)
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
          (blocked = true; raise Thread::Blocked) if t.nil? || (Thread.__pending_include?(t) && Thread.__pending_size <= 1)
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
