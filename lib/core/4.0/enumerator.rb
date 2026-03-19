class Enumerator
  include Enumerable

  class Yielder
    def initialize(&block)
      @block = block
    end

    def yield(*args)
      if @block
        @block.call(*args)
      else
        Fiber.yield(args)
      end
    end

    def <<(*args)
      self.yield(*args)
      self
    end

    def to_proc
      y = self
      proc { |*args| y.yield(*args) }
    end
  end

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

  def next_values = __next_values_raw__

  def peek
    vals = __peek_values_raw__
    vals.empty? ? nil : (vals.length == 1 ? vals[0] : vals)
  end

  def peek_values
    __peek_values_raw__
  end

  def feed(val)
    @feed = val
    nil
  end

  def rewind
    @receiver.rewind if @receiver.respond_to?(:rewind)
    @fiber = nil
    @peeked = false
    @peeked_vals = nil
    @feed = nil
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

  def self.produce(initial = nil, &block)
    Enumerator.new do |y|
      val = initial
      loop do
        y << val
        begin
          val = block.call(val)
        rescue StopIteration
          break
        end
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
    self
  end

  def __ensure_fiber__
    return if @fiber
    if @block
      b = @block
      @fiber = Fiber.new { b.call(Yielder.new { |*args| Fiber.yield(args) }); nil }
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
  end

  def __advance__
    __ensure_fiber__
    unless @fiber.alive?
      exc = StopIteration.new("iteration reached an end")
      exc.instance_variable_set(:@result, @_enum_result)
      raise exc
    end
    feed_val = @feed
    @feed = nil
    vals = @fiber.resume(feed_val)
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
  def inspect
    if @receiver.nil? && @block.nil?
      "#<Enumerator::Lazy: uninitialized>"
    elsif @receiver
      args_str = @method_args.empty? ? "" : "(#{@method_args.map(&:inspect).join(', ')})"
      "#<Enumerator::Lazy: #{@receiver.inspect}:#{@method_name}#{args_str}>"
    else
      "#<Enumerator::Lazy: generator>"
    end
  end
end

class Enumerator::Chain
  include Enumerable

  def each(&block)
    return to_enum(:each) unless block
    @enums.each { |e| e.each(&block) }
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
    @enums.each { |e| e.rewind if e.respond_to?(:rewind) }
    self
  end

  def inspect
    "#<Enumerator::Chain: #{@enums.inspect}>"
  end

  private

  def initialize(*enums)
    raise FrozenError, "can't modify frozen Enumerator::Chain" if frozen?
    @enums = enums
    self
  end
end

class Enumerator
  class ArithmeticSequence < Enumerator
    # Supports both Range#step (receiver is a Range) and Numeric#step (receiver is a Numeric).
    def begin
      @receiver.is_a?(Range) ? @receiver.begin : @receiver
    end

    def end
      if @receiver.is_a?(Range)
        @receiver.end
      else
        kw = @method_kwargs || {}
        kw[:to]
      end
    end

    def step
      if @receiver.is_a?(Range)
        @method_args.first
      else
        kw = @method_kwargs || {}
        kw[:by] || @method_args.first || 1
      end
    end

    def exclude_end?
      @receiver.is_a?(Range) ? @receiver.exclude_end? : false
    end

    def ==(other)
      return false unless other.is_a?(ArithmeticSequence)
      self.begin == other.begin && self.end == other.end &&
        self.step == other.step && exclude_end? == other.exclude_end?
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
        "((#{@receiver.inspect}).#{@method_name}#{args_str})"
      end
    end

    alias to_s inspect
  end
end
