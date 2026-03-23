class Enumerator
  include Enumerable

  class Yielder
    def initialize(&block)
      @block = block
      self
    end

    def yield(*args)
      if @block
        @block.call(*args)
      else
        Fiber.yield(args)
      end
    end

    def <<(arg)
      self.yield(arg)
      self
    end

    def to_proc
      y = self
      proc { |*args| y.yield(*args) }
    end
  end

  def next_values = __next_values_raw__

  def self._from_method(receiver, method_name, method_args, size_block = nil, method_kwargs = {})
    e = allocate
    e.instance_variable_set(:@receiver, receiver)
    e.instance_variable_set(:@method_name, method_name)
    e.instance_variable_set(:@method_args, method_args || [])
    e.instance_variable_set(:@method_kwargs, method_kwargs || {})
    e.instance_variable_set(:@size_block, size_block)
    e.instance_variable_set(:@block, nil)
    e.instance_variable_set(:@size, nil)
    e.instance_variable_set(:@fiber, nil)
    e.instance_variable_set(:@peeked, false)
    e.instance_variable_set(:@peeked_vals, nil)
    e.instance_variable_set(:@feed, nil)
    e.instance_variable_set(:@_feed_pending, false)
    e.instance_variable_set(:@_fiber_started, false)
    e
  end

  def each(*extra_args, **extra_kwargs, &block)
    unless block
      return self if extra_args.empty? && extra_kwargs.empty?
      # Return new enumerator with extra args appended
      if @receiver
        merged_kwargs = (@method_kwargs || {}).merge(extra_kwargs)
        self.class._from_method(@receiver, @method_name, @method_args + extra_args, @size_block, merged_kwargs)
      else
        self
      end
    else
      if @receiver
        # Method-mode: call the method directly and return its return value
        combined_kwargs = (@method_kwargs || {}).merge(extra_kwargs)
        if combined_kwargs.empty?
          @receiver.send(@method_name, *(@method_args + extra_args), &block)
        else
          @receiver.send(@method_name, *(@method_args + extra_args), **combined_kwargs, &block)
        end
      else
        # Block-mode: iterate via fiber
        rewind
        begin
          loop do
            vals = __advance__
            result = yield(vals.empty? ? nil : (vals.length == 1 ? vals[0] : vals))
            @feed = result
          end
        rescue StopIteration
        end
        self
      end
    end
  end

  def next
    vals = __next_values_raw__
    vals.empty? ? nil : (vals.length == 1 ? vals[0] : vals)
  end

  def peek
    vals = __peek_values_raw__
    vals.empty? ? nil : (vals.length == 1 ? vals[0] : vals)
  end

  def peek_values
    __peek_values_raw__
  end

  def feed(val)
    raise TypeError, "feed value already set" if @_fiber_started && @_feed_pending
    @feed = val
    @_feed_pending = true
    nil
  end

  def rewind
    @receiver.rewind if @receiver.respond_to?(:rewind)
    @fiber = nil
    @peeked = false
    @peeked_vals = nil
    @feed = nil
    @_feed_pending = false
    @_fiber_started = false
    self
  end

  def size
    if @size_block
      @size_block.call
    elsif @size.respond_to?(:call)
      @size.call
    else
      @size
    end
  end

  def count
    s = size
    s.nil? ? to_a.length : s
  end

  def inspect
    if @receiver.nil? && @block.nil?
      return "#<Enumerator: uninitialized>"
    end
    if @receiver
      args_str = @method_args.empty? ? "" : "(#{@method_args.map(&:inspect).join(', ')})"
      "#<Enumerator: #{@receiver.inspect}:#{@method_name}#{args_str}>"
    else
      "#<Enumerator: generator>"
    end
  end
  alias to_s inspect

  def self.produce(*initial_args, &block)
    raise ArgumentError, "wrong number of arguments (given #{initial_args.size}, expected 0..1)" if initial_args.size > 1
    has_initial = !initial_args.empty?
    Enumerator.new do |y|
      val = has_initial ? initial_args[0] : nil
      y << val if has_initial
      loop do
        begin
          val = block.call(val)
        rescue StopIteration
          break
        end
        y << val
      end
    end
  end

  def to_a
    result = []
    each { |*x| result << (x.length == 1 ? x[0] : x) }
    result
  end
  alias entries to_a

  def first(n = nil)
    if n.nil?
      begin; return self.next; rescue StopIteration; return nil; end if @receiver || @block
      peek
    else
      result = []
      begin
        n.times { result << self.next }
      rescue StopIteration
      end
      rewind
      result
    end
  end

  def take(n)
    result = []
    count = 0
    each { |*x| result << (x.length == 1 ? x[0] : x); count += 1; break if count >= n }
    result
  end

  def map(&block)
    return to_enum(:map) unless block
    result = []
    each { |*x| result << block.call(*x) }
    result
  end
  alias collect map

  def each_with_index(&ewi_block)
    return to_enum(:each_with_index) { size } unless ewi_block
    i = 0
    each { |*x|
      v = ewi_block.call(x.length == 1 ? x[0] : x, i)
      i += 1
      v
    }
  end

  def each_with_object(obj, &block)
    return to_enum(:each_with_object, obj) unless block
    each { |*x| block.call(x.length == 1 ? x[0] : x, obj) }
    obj
  end

  def with_index(offset = 0, &block)
    return to_enum(:with_index, offset) { size } unless block
    offset = if offset.nil?
      0
    elsif offset.is_a?(Integer)
      offset
    elsif offset.is_a?(Float)
      offset.to_i
    elsif offset.respond_to?(:to_int)
      offset.to_int
    else
      raise TypeError, "no implicit conversion of #{offset.class} into Integer"
    end
    i = offset
    each { |*x|
      v = block.call(x.length == 1 ? x[0] : x, i)
      i += 1
      v
    }
  end

  def with_object(obj, &block)
    each_with_object(obj, &block)
  end

  def +(other)
    Enumerator::Chain.new(self, other)
  end
  private

  def initialize(size = nil, &block)
    raise FrozenError, "can't modify frozen Enumerator" if frozen?
    @block = block
    @size = size
    @receiver = nil
    @method_name = nil
    @method_args = []
    @method_kwargs = {}
    @size_block = nil
    @fiber = nil
    @peeked = false
    @peeked_vals = nil
    @feed = nil
    @_feed_pending = false
    @_fiber_started = false
    self
  end

  def __ensure_fiber__
    return if @fiber
    if @block
      b = @block
      enum = self
      @fiber = Fiber.new { enum.instance_variable_set(:@_enum_result, b.call(Yielder.new { |*args| Fiber.yield(args) })); nil }
    else
      recv = @receiver
      meth = @method_name
      args = @method_args
      kwargs = @method_kwargs || {}
      enum = self
      @fiber = Fiber.new do
        result = if kwargs.empty?
          recv.send(meth, *args) { |*vals| Fiber.yield(vals) }
        else
          recv.send(meth, *args, **kwargs) { |*vals| Fiber.yield(vals) }
        end
        enum.instance_variable_set(:@_enum_result, result)
        nil
      end
    end
    @_fiber_started = false
  end

  def __advance__
    __ensure_fiber__
    unless @fiber.alive?
      exc = StopIteration.new("iteration reached an end")
      exc.instance_variable_set(:@result, @_enum_result)
      raise exc
    end
    unless @_fiber_started
      @_fiber_started = true
      vals = @fiber.resume(nil)
    else
      feed_val = @feed
      @feed = nil
      @_feed_pending = false
      vals = @fiber.resume(feed_val)
    end
    if vals.nil?
      exc = StopIteration.new("iteration reached an end")
      exc.instance_variable_set(:@result, @_enum_result)
      raise exc
    end
    vals
  end

  def __next_values_raw__
    if @peeked
      @peeked = false
      vals = @peeked_vals
      @peeked_vals = nil
      return vals
    end
    begin
      __advance__
    rescue StopIteration
      raise
    rescue => e
      @fiber = nil  # fiber was killed by exception; restart on next call
      raise
    end
  end

  def __peek_values_raw__
    unless @peeked
      @peeked_vals = __advance__
      @peeked = true
    end
    @peeked_vals
  end
end

class Enumerator::Generator
  include Enumerable

  def each(*args, &block)
    raise LocalJumpError, "no block given (yield)" unless block
    yielder = Enumerator::Yielder.new(&block)
    @block.call(yielder, *args)
  end
  private

  def initialize(&block)
    raise FrozenError, "can't modify frozen Enumerator::Generator" if frozen?
    raise LocalJumpError, "no block given" unless block
    @block = block
    self
  end
end

class Enumerator::Lazy < Enumerator
  def initialize(obj, size = nil, &block)
    raise FrozenError, "can't modify frozen Enumerator::Lazy" if frozen?
    raise ArgumentError, "tried to create Proc object without a block" unless block
    @receiver       = obj
    @_lazy_xform    = block   # proc { |yielder, *vals| ... } transform
    @_xform_factory = nil     # when set: called to produce a fresh xform per _lazy_eval
    @_grouped_eval  = nil     # when set: replaces _lazy_eval entirely (for chunk/slice etc.)
    @_lazy_size     = size    # explicit size
    # Inherited Enumerator ivars (unused in lazy path)
    @method_name = nil
    @method_args = []
    @method_kwargs = {}
    @size_block  = nil
    @size        = size
    @block       = nil
    @fiber       = nil
    @peeked      = false
    @peeked_vals = nil
    @feed        = nil
    @_feed_pending = false
    @_fiber_started = false
    self
  end

  # Internal evaluation — does NOT rescue StopIteration (callers do).
  # Calls output block with *vals for each element in the lazy chain.
  def _lazy_eval(*extra_args, &output)
    # Grouped eval (chunk, slice_*): completely custom evaluation strategy
    if @_grouped_eval
      @_grouped_eval.call(output, *extra_args)
      return
    end
    # Per-element transform: factory produces a fresh xform for stateful methods
    xform = @_xform_factory ? @_xform_factory.call : @_lazy_xform
    yielder = Enumerator::Yielder.new { |*vals| output.call(*vals) }
    if @receiver.is_a?(Enumerator::Lazy)
      @receiver._lazy_eval(*extra_args) { |*args| xform.call(yielder, *args) }
    else
      @receiver.each(*extra_args) { |*args| xform.call(yielder, *args) }
    end
  end
  protected :_lazy_eval

  def each(*args, &block)
    return self unless block
    begin
      _lazy_eval(*args) { |*vals| block.call(*vals) }
    rescue StopIteration
    end
    self
  end

  def force(*args)
    result = []
    begin
      _lazy_eval(*args) { |*vals| result << (vals.empty? ? nil : (vals.length == 1 ? vals[0] : vals)) }
    rescue StopIteration
    end
    result
  end
  alias to_a force
  alias entries force

  def first(n = nil)
    if n.nil?
      take(1).to_a[0]
    else
      take(n).to_a
    end
  end

  def size
    return @_lazy_size.call if @_lazy_size.respond_to?(:call)
    @_lazy_size
  end

  def lazy = self

  def map(&block)
    return to_enum(:map) { size } unless block
    Enumerator::Lazy.new(self, size) { |y, *args| y << block.call(*args) }
  end
  alias collect map

  def select(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    Enumerator::Lazy.new(self) do |y, *args|
      val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
      y << val if block.call(val)
    end
  end
  alias filter select
  alias find_all select

  def reject(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    Enumerator::Lazy.new(self) do |y, *args|
      val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
      y << val unless block.call(val)
    end
  end

  def flat_map(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    Enumerator::Lazy.new(self) do |y, *args|
      result = block.call(*args)  # initial form: pass *args to block
      if result.is_a?(Enumerator::Lazy)
        # Use _lazy_eval so StopIteration propagates through the chain
        result._lazy_eval { |v| y << v }
      elsif result.is_a?(Array)
        # Array#each propagates StopIteration from the block
        result.each { |v| y << v }
      else
        y << result
      end
    end
  end
  alias collect_concat flat_map

  def take(n)
    n = n.to_int if n.respond_to?(:to_int) && !n.is_a?(Integer)
    raise ArgumentError, "attempt to take negative size" if n < 0
    sz = size
    new_size = sz ? [sz, n].min : n
    return Enumerator::Lazy.new([], 0) { |y, *args| } if n == 0
    the_n = n
    lazy = Enumerator::Lazy.new(self, new_size) { }
    lazy.instance_variable_set(:@_xform_factory, proc {
      remaining = the_n
      proc { |y, *args|
        raise StopIteration if remaining <= 0
        val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
        y << val
        remaining -= 1
        raise StopIteration if remaining <= 0
      }
    })
    lazy
  end

  def take_while(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    Enumerator::Lazy.new(self) do |y, *args|
      val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
      raise StopIteration unless block.call(*args)  # initial form for block call
      y << val
    end
  end

  def drop(n)
    n = n.to_int if n.respond_to?(:to_int) && !n.is_a?(Integer)
    raise ArgumentError, "attempt to drop negative size" if n < 0
    sz = size
    new_size = sz ? [sz - n, 0].max : nil
    the_n = n
    lazy = Enumerator::Lazy.new(self, new_size) { }
    lazy.instance_variable_set(:@_xform_factory, proc {
      skipped = 0
      proc { |y, *args|
        val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
        if skipped < the_n
          skipped += 1
        else
          y << val
        end
      }
    })
    lazy
  end

  def drop_while(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    the_block = block
    lazy = Enumerator::Lazy.new(self) { }
    lazy.instance_variable_set(:@_xform_factory, proc {
      dropping = true
      proc { |y, *args|
        val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
        if dropping
          unless the_block.call(*args)
            dropping = false
            y << val
          end
        else
          y << val
        end
      }
    })
    lazy
  end

  def filter_map(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    Enumerator::Lazy.new(self) do |y, *args|
      val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
      result = block.call(val)
      y << result if result
    end
  end

  def uniq(&block)
    the_block = block
    lazy = Enumerator::Lazy.new(self) { }
    lazy.instance_variable_set(:@_xform_factory, proc {
      seen = {}
      proc { |y, *args|
        val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
        key = the_block ? the_block.call(val) : val
        unless seen.key?(key)
          seen[key] = true
          y << val
        end
      }
    })
    lazy
  end

  def compact
    Enumerator::Lazy.new(self) do |y, *args|
      val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
      y << val unless val.nil?
    end
  end

  def grep(pattern, &block)
    if block
      Enumerator::Lazy.new(self) do |y, *args|
        val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
        y << block.call(val) if pattern === val
      end
    else
      Enumerator::Lazy.new(self) do |y, *args|
        val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
        y << val if pattern === val
      end
    end
  end

  def grep_v(pattern, &block)
    if block
      Enumerator::Lazy.new(self) do |y, *args|
        val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
        y << block.call(val) unless pattern === val
      end
    else
      Enumerator::Lazy.new(self) do |y, *args|
        val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
        y << val unless pattern === val
      end
    end
  end

  def zip(*others, &block)
    others_arrays = others.map do |o|
      if o.respond_to?(:force)
        o.force
      elsif o.respond_to?(:to_a)
        o.to_a
      else
        raise TypeError, "wrong argument type #{o.class} (must respond to :each)"
      end
    end
    if block
      # Block form: evaluate immediately like non-lazy Enumerable#zip
      each_with_index { |v, i| block.call([v] + others_arrays.map { |a| a[i] }) }
      return nil
    end
    the_others = others_arrays
    lazy = Enumerator::Lazy.new(self, size) { }
    lazy.instance_variable_set(:@_xform_factory, proc {
      i = 0
      proc { |y, *args|
        val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
        y << ([val] + the_others.map { |a| a[i] })
        i += 1
      }
    })
    lazy
  end

  def chunk(&block)
    unless block
      # Without a block: return a Lazy where each { pred } uses pred as chunk key
      source = self
      lazy = Enumerator::Lazy.new(self) { }
      lazy.instance_variable_set(:@_lazy_size, nil)
      lazy.define_singleton_method(:each) do |*args, &pred|
        return self unless pred
        # pred is the chunk key function — return the resulting chunked lazy
        source.chunk(&pred)
      end
      return lazy
    end
    source = self
    the_block = block
    lazy = Enumerator::Lazy.new(self) { }
    lazy.instance_variable_set(:@_lazy_size, nil)
    lazy.instance_variable_set(:@_grouped_eval, proc { |output, *extra_args|
      current_key = nil
      current_group = nil
      begin
        source._lazy_eval(*extra_args) do |*args|
          val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
          key = the_block.call(val)
          if current_group.nil?
            current_key = key
            current_group = [val]
          elsif key == current_key
            current_group << val
          else
            output.call(current_key, current_group)
            current_key = key
            current_group = [val]
          end
        end
      rescue StopIteration
        raise
      end
      output.call(current_key, current_group) if current_group
    })
    lazy
  end

  def chunk_while(&block)
    return to_enum(:chunk_while) unless block
    source = self
    the_block = block
    lazy = Enumerator::Lazy.new(self) { }
    lazy.instance_variable_set(:@_lazy_size, nil)
    lazy.instance_variable_set(:@_grouped_eval, proc { |output, *extra_args|
      current_group = nil
      prev_val = nil
      begin
        source._lazy_eval(*extra_args) do |*args|
          val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
          if current_group.nil?
            current_group = [val]
          elsif the_block.call(prev_val, val)
            current_group << val
          else
            output.call(current_group)
            current_group = [val]
          end
          prev_val = val
        end
      rescue StopIteration
        raise
      end
      output.call(current_group) if current_group
    })
    lazy
  end

  def slice_before(pattern = nil, &block)
    return to_enum(:slice_before) unless pattern || block
    source = self
    pred = if block
      block
    else
      proc { |val| pattern === val }
    end
    lazy = Enumerator::Lazy.new(self) { }
    lazy.instance_variable_set(:@_lazy_size, nil)
    lazy.instance_variable_set(:@_grouped_eval, proc { |output, *extra_args|
      current_group = nil
      begin
        source._lazy_eval(*extra_args) do |*args|
          val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
          if pred.call(val)
            output.call(current_group) if current_group
            current_group = [val]
          else
            (current_group ||= []) << val
          end
        end
      rescue StopIteration
        raise
      end
      output.call(current_group) if current_group
    })
    lazy
  end

  def slice_after(pattern = nil, &block)
    return to_enum(:slice_after) unless pattern || block
    source = self
    pred = if block
      block
    else
      proc { |val| pattern === val }
    end
    lazy = Enumerator::Lazy.new(self) { }
    lazy.instance_variable_set(:@_lazy_size, nil)
    lazy.instance_variable_set(:@_grouped_eval, proc { |output, *extra_args|
      current_group = []
      begin
        source._lazy_eval(*extra_args) do |*args|
          val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
          current_group << val
          if pred.call(val)
            output.call(current_group)
            current_group = []
          end
        end
      rescue StopIteration
        raise
      end
      output.call(current_group) unless current_group.empty?
    })
    lazy
  end

  def slice_when(&block)
    return to_enum(:slice_when) unless block
    source = self
    the_block = block
    lazy = Enumerator::Lazy.new(self) { }
    lazy.instance_variable_set(:@_lazy_size, nil)
    lazy.instance_variable_set(:@_grouped_eval, proc { |output, *extra_args|
      current_group = nil
      prev_val = nil
      begin
        source._lazy_eval(*extra_args) do |*args|
          val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
          if current_group.nil?
            current_group = [val]
          elsif the_block.call(prev_val, val)
            output.call(current_group)
            current_group = [val]
          else
            current_group << val
          end
          prev_val = val
        end
      rescue StopIteration
        raise
      end
      output.call(current_group) if current_group
    })
    lazy
  end

  def each_with_object(obj, &block)
    return to_enum(:each_with_object, obj) unless block
    each { |v| block.call(v, obj) }
    obj
  end

  def each_with_index(&block)
    return to_enum(:each_with_index) { size } unless block
    i = 0
    each { |v| block.call(v, i); i += 1 }
  end

  def with_index(offset = 0, &block)
    if offset.nil?
      offset = 0
    elsif !offset.is_a?(Integer)
      begin
        offset = offset.to_int
      rescue NoMethodError
        raise TypeError, "no implicit conversion into Integer"
      end
    end
    if block
      the_block = block
      the_offset = offset
      lazy = Enumerator::Lazy.new(self, size) { }
      lazy.instance_variable_set(:@_xform_factory, proc {
        i = the_offset
        proc { |y, *args|
          val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
          the_block.call(val, i)
          i += 1
          y << val
        }
      })
      lazy
    else
      the_offset = offset
      lazy = Enumerator::Lazy.new(self, size) { }
      lazy.instance_variable_set(:@_xform_factory, proc {
        i = the_offset
        proc { |y, *args|
          val = args.empty? ? nil : (args.length == 1 ? args[0] : args)
          y.yield(val, i)
          i += 1
        }
      })
      lazy
    end
  end

  def eager
    Enumerator.new { |y| each { |*v| y.yield(*v) } }
  end

  def with_object(obj, &block)
    each_with_object(obj, &block)
  end

  def count(val = (no_arg = true), &block)
    if block
      n = 0
      each { |v| n += 1 if block.call(v) }
      n
    elsif !no_arg
      n = 0
      each { |v| n += 1 if v == val }
      n
    else
      s = size
      s.nil? ? to_a.length : s
    end
  end

  def to_enum(method_name = :each, *args, **kwargs, &size_block)
    Enumerator._from_method(self, method_name, args, size_block, kwargs)
  end
  alias enum_for to_enum

  def inspect
    if @receiver.nil? && @_lazy_xform.nil?
      "#<Enumerator::Lazy: uninitialized>"
    elsif @receiver
      "#<Enumerator::Lazy: #{@receiver.inspect}>"
    else
      "#<Enumerator::Lazy: generator>"
    end
  end

  private

  def initialize_copy(source)
    super
    self
  end

  def __ensure_fiber__
    return if @fiber
    enum = self
    @fiber = Fiber.new do
      begin
        enum.send(:_lazy_eval) { |*vals| Fiber.yield(vals) }
      rescue StopIteration
      end
      nil
    end
    @_fiber_started = false
  end
end

class Enumerator::Chain
  include Enumerable

  def each(&block)
    return to_enum(:each) unless block
    @_iterated_count = 0
    @enums.each do |e|
      @_iterated_count += 1
      e.each(&block)
    end
    self
  end

  def size
    total = 0
    @enums.each do |e|
      s = e.respond_to?(:size) ? e.size : nil
      return nil if s.nil?
      return Float::INFINITY if s == Float::INFINITY
      total += s
    end
    total
  end

  def rewind
    count = @_iterated_count || 0
    @enums.first(count).reverse_each { |e| e.rewind if e.respond_to?(:rewind) }
    @_iterated_count = 0
    self
  end

  def inspect
    return "#<Enumerator::Chain: uninitialized>" if @enums.nil?
    "#<Enumerator::Chain: #{@enums.inspect}>"
  end
  private

  def initialize(*enums)
    raise FrozenError, "can't modify frozen Enumerator::Chain" if frozen?
    @enums = enums
    @_iterated_count = 0
    self
  end
end

class Enumerator
  class ArithmeticSequence < Enumerator
    @_internal_allocate = false

    def self.new(...)
      raise NoMethodError, "undefined method 'new' for Enumerator::ArithmeticSequence:Class"
    end

    def self.allocate
      raise TypeError, "allocator undefined for Enumerator::ArithmeticSequence" unless @_internal_allocate
      @_internal_allocate = false
      super
    end

    def self._from_method(receiver, method_name, method_args, size_block = nil, method_kwargs = {})
      @_internal_allocate = true
      super
    end

    # Supports both Range#step (receiver is a Range) and Numeric#step (receiver is a Numeric).
    def begin
      @receiver.is_a?(Range) ? @receiver.begin : @receiver
    end

    def end
      if @receiver.is_a?(Range)
        @receiver.end
      else
        kw = @method_kwargs || {}
        kw.key?(:to) ? kw[:to] : @method_args[0]
      end
    end

    def step
      if @receiver.is_a?(Range)
        @method_args.first || 1
      else
        kw = @method_kwargs || {}
        if kw.key?(:by)
          kw[:by]
        elsif @method_args.length >= 2
          @method_args[1]
        else
          1
        end
      end
    end

    def exclude_end?
      @receiver.is_a?(Range) ? @receiver.exclude_end? : false
    end

    def each(&block)
      return self unless block
      super(&block)
      self
    end

    def ==(other)
      return false unless other.is_a?(ArithmeticSequence)
      self.begin == other.begin && self.end == other.end &&
        self.step == other.step && exclude_end? == other.exclude_end?
    end

    def hash
      [self.begin, self.end, self.step, exclude_end?].hash
    end

    def last
      b = self.begin
      e = self.end
      s = self.step
      return nil if e.nil?
      n = exclude_end? ? ((e - b) / s.to_f).ceil - 1 : ((e - b) / s.to_f).floor
      n < 0 ? nil : b + n * s
    end

    def size
      b = self.begin
      e = self.end
      s = self.step
      return Float::INFINITY if e.nil? || (e.respond_to?(:infinite?) && e.infinite? == 1)
      n = exclude_end? ? ((e - b) / s.to_f).ceil : ((e - b) / s.to_f).floor + 1
      [n, 0].max
    end

    def inspect
      if @receiver.is_a?(Range)
        args_str = @method_args.empty? ? "" : "(#{@method_args.map(&:inspect).join(', ')})"
        "((#{@receiver.inspect}).#{@method_name}#{args_str})"
      else
        kw = @method_kwargs || {}
        parts = []
        parts << "by: #{kw[:by].inspect}" if kw.key?(:by)
        parts << "to: #{kw[:to].inspect}" if kw.key?(:to)
        args_part = @method_args.map(&:inspect)
        all_args = args_part + parts
        args_str = all_args.empty? ? "" : "(#{all_args.join(', ')})"
        "(#{@receiver.inspect}.#{@method_name}#{args_str})"
      end
    end
    alias to_s inspect
  end

  class Product < Enumerator
    def initialize(*enumerables)
      raise FrozenError, "can't modify frozen Enumerator::Product" if frozen?
      @enumerables = enumerables
      # Set inherited Enumerator ivars directly (don't call super with a block)
      @block = nil
      @receiver = nil
      @method_name = nil
      @method_args = []
      @method_kwargs = {}
      @size_block = nil
      @size = nil
      @fiber = nil
      @peeked = false
      @peeked_vals = nil
      @feed = nil
      @_feed_pending = false
      @_fiber_started = false
      self
    end

    def each(&block)
      return to_enum(:each) { size } unless block
      if @enumerables.empty?
        block.call([])
      else
        __product_each__(0, [], block)
      end
      self
    end

    def rewind
      @enumerables&.each { |e| e.rewind if e.respond_to?(:rewind) }
      self
    end

    def inspect
      return "#<Enumerator::Product: uninitialized>" if @enumerables.nil?
      seen = (Fiber[:__product_inspect__] ||= {})
      return "#<Enumerator::Product: ...>" if seen[object_id]
      seen[object_id] = true
      begin
        "#<Enumerator::Product: #{@enumerables.inspect}>"
      ensure
        seen.delete(object_id)
      end
    end

    def size
      return 1 if @enumerables.empty?
      @enumerables.reduce(1) do |acc, e|
        s = e.respond_to?(:size) ? e.size : nil
        return nil if s.nil?
        return Float::INFINITY if s == Float::INFINITY
        return nil unless s.is_a?(Integer)
        acc * s
      end
    end

    private

    def initialize_copy(source)
      return self if source.equal?(self)
      raise FrozenError, "can't modify frozen Enumerator::Product" if frozen?
      raise TypeError, "initialize_copy should take same class object" unless source.class == self.class
      raise ArgumentError, "uninitialized product" if source.instance_variable_get(:@enumerables).nil?
      @enumerables = source.instance_variable_get(:@enumerables).dup
      @fiber = nil
      @peeked = false
      @peeked_vals = nil
      @feed = nil
      @_feed_pending = false
      @_fiber_started = false
      self
    end

    def __product_each__(idx, current, block)
      if idx == @enumerables.size
        block.call(current.dup)
        return
      end
      @enumerables[idx].each_entry do |item|
        current.push(item)
        __product_each__(idx + 1, current, block)
        current.pop
      end
    end
  end

  def self.product(*enumerables, **kwargs, &block)
    unless kwargs.empty?
      raise ArgumentError, "unknown keywords: #{kwargs.keys.map { |k| ":#{k}" }.join(", ")}"
    end
    prod = Product.new(*enumerables)
    if block
      prod.each(&block)
      return nil
    end
    prod
  end
end
