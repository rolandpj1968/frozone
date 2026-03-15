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

  def initialize(size = nil, &block)
    raise FrozenError, "can't modify frozen Enumerator" if frozen?
    @block = block
    @size = size
    @receiver = nil
    @method_name = nil
    @method_args = []
    @size_block = nil
    @fiber = nil
    @peeked = false
    @peeked_vals = nil
    @feed = nil
    self
  end

  private :initialize

  def self._from_method(receiver, method_name, method_args, size_block = nil)
    e = allocate
    e.instance_variable_set(:@receiver, receiver)
    e.instance_variable_set(:@method_name, method_name)
    e.instance_variable_set(:@method_args, method_args || [])
    e.instance_variable_set(:@size_block, size_block)
    e.instance_variable_set(:@block, nil)
    e.instance_variable_set(:@size, nil)
    e.instance_variable_set(:@fiber, nil)
    e.instance_variable_set(:@peeked, false)
    e.instance_variable_set(:@peeked_vals, nil)
    e.instance_variable_set(:@feed, nil)
    e
  end

  def each(*extra_args, &block)
    unless block
      return self if extra_args.empty?
      # Return new enumerator with extra args appended
      if @receiver
        self.class._from_method(@receiver, @method_name, @method_args + extra_args, @size_block)
      else
        self
      end
    else
      if @receiver
        # Method-mode: call the method directly and return its return value
        @receiver.send(@method_name, *(@method_args + extra_args), &block)
      else
        # Block-mode: iterate via fiber
        rewind
        begin
          loop do
            vals = _advance
            result = yield(vals.length == 1 ? vals[0] : vals)
            @feed = result
          end
        rescue StopIteration
        end
        self
      end
    end
  end

  def next
    vals = _next_values_raw
    vals.length == 1 ? vals[0] : vals
  end

  def next_values
    _next_values_raw
  end

  def peek
    vals = _peek_values_raw
    vals.length == 1 ? vals[0] : vals
  end

  def peek_values
    _peek_values_raw
  end

  def feed(val)
    @feed = val
    nil
  end

  def rewind
    @fiber = nil
    @peeked = false
    @peeked_vals = nil
    @feed = nil
    self
  end

  def size
    if @size_block
      @size_block.call
    elsif @size.is_a?(Proc)
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
    each { |x| result << x }
    result
  end

  alias entries to_a

  def first(n = nil)
    if n.nil?
      begin; next; rescue StopIteration; return nil; end if @receiver || @block
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
    each { |x| result << x; count += 1; break if count >= n }
    result
  end

  def map(&block)
    return to_enum(:map) unless block
    result = []
    each { |x| result << (block ? block.call(x) : yield(x)) }
    result
  end

  alias collect map

  def each_with_index
    return to_enum(:each_with_index) unless block_given?
    i = 0
    each { |x| yield x, i; i += 1 }
    self
  end

  def each_with_object(obj, &block)
    return to_enum(:each_with_object, obj) unless block
    each { |x| block.call(x, obj) }
    obj
  end

  def with_index(offset = 0, &block)
    return to_enum(:with_index, offset) unless block
    each_with_index { |x, i| block.call(x, i + offset) }
    self
  end

  def with_object(obj, &block)
    each_with_object(obj, &block)
  end

  def +(other)
    Enumerator::Chain.new(self, other)
  end

  private

  def _ensure_fiber
    return if @fiber
    if @block
      b = @block
      @fiber = Fiber.new { b.call(Yielder.new { |*args| Fiber.yield(args) }); nil }
    else
      recv = @receiver
      meth = @method_name
      args = @method_args
      enum = self
      @fiber = Fiber.new do
        result = recv.send(meth, *args) { |*vals| Fiber.yield(vals) }
        enum.instance_variable_set(:@_enum_result, result)
        nil
      end
    end
  end

  def _advance
    _ensure_fiber
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

  def _next_values_raw
    if @peeked
      @peeked = false
      vals = @peeked_vals
      @peeked_vals = nil
      return vals
    end
    _advance
  end

  def _peek_values_raw
    unless @peeked
      @peeked_vals = _advance
      @peeked = true
    end
    @peeked_vals
  end
end

class Enumerator::Generator
  include Enumerable

  def initialize(&block)
    raise FrozenError, "can't modify frozen Enumerator::Generator" if frozen?
    raise LocalJumpError, "no block given" unless block
    @block = block
    self
  end

  private :initialize

  def each(*args, &block)
    raise LocalJumpError, "no block given (yield)" unless block
    yielder = Enumerator::Yielder.new(&block)
    @block.call(yielder, *args)
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

  def initialize(*enums)
    raise FrozenError, "can't modify frozen Enumerator::Chain" if frozen?
    @enums = enums
    self
  end

  private :initialize

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
end

class Enumerator
  class ArithmeticSequence < Enumerator
    # Returned by Range#step for numeric ranges
  end
end
