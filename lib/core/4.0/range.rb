class Range
  def each(&block)
    Intrinsics.range_each(self, block)
  end
  def to_a           = Intrinsics.range_to_a(self)
  def include?(val)  = Intrinsics.range_include(self, val)
  alias member? include?
  alias cover? include?
  def size           = Intrinsics.range_size(self)
  alias count size
  alias length size
  def begin          = Intrinsics.range_begin(self)
  def end            = Intrinsics.range_end(self)
  def exclude_end?   = Intrinsics.range_exclude_end(self)
  def first          = self.begin
  def last           = self.end
  def min            = self.begin
  def max            = self.exclusive? ? self.end - 1 : self.end
  def each_with_index; i = 0; each { |x| yield x, i; i += 1 }; self; end
  def map;    r = []; each { |x| r << yield(x) };      r; end
  def select; r = []; each { |x| r << x if yield(x) }; r; end
  def any?  = (each { |x| return true  if yield(x) }; false)
  def all?  = (each { |x| return false unless yield(x) }; true)
  def none? = (each { |x| return false if yield(x) }; true)
  def to_s  = Intrinsics.range_to_s(self)
  def ==(other)
    return false unless other.is_a?(Range)
    self.begin == other.begin && self.end == other.end && self.exclude_end? == other.exclude_end?
  end
  alias eql? ==
  def inspect = to_s
  def step(n = 1, &block)
    return to_enum(:step, n) unless block
    i = self.begin
    e = self.end
    while exclude_end? ? i < e : i <= e
      yield i
      i += n
    end
    self
  end
  def reduce(init = nil, &block)
    if init.nil?
      acc = nil
      first = true
      each { |x| first ? (acc = x; first = false) : (acc = block.call(acc, x)) }
    else
      acc = init
      each { |x| acc = block.call(acc, x) }
    end
    acc
  end
  alias inject reduce
  def find(&block); each { |x| return x if yield(x) }; nil; end
  alias detect find
  def sum(init = 0); inject(init) { |a, x| a + x }; end
  def flat_map(&block); map(&block).flatten(1); end
  alias collect_concat flat_map
  def each_slice(n)
    return to_enum(:each_slice, n) unless block_given?
    slice = []
    each do |x|
      slice << x
      if slice.length == n
        yield slice
        slice = []
      end
    end
    yield slice unless slice.empty?
    self
  end
  def each_cons(n)
    return to_enum(:each_cons, n) unless block_given?
    buf = []
    each do |x|
      buf << x
      if buf.length == n
        yield buf.dup
        buf.shift
      end
    end
    self
  end
  def zip(*others)
    result = []
    to_a.each_with_index { |x, i| result << ([x] + others.map { |o| o.to_a[i] }) }
    result
  end
  def reverse_each(&block)
    return to_enum(:reverse_each) unless block
    to_a.reverse_each(&block)
    self
  end
  def sort; to_a.sort; end
  def sort_by(&block); to_a.sort_by(&block); end
  def min_by(&block); to_a.min_by(&block); end
  def max_by(&block); to_a.max_by(&block); end
  def count(&block); block ? to_a.count(&block) : size; end
  def take(n); to_a.take(n); end
  def drop(n); to_a.drop(n); end
  def first(n = nil); n ? to_a.first(n) : self.begin; end
  def last(n = nil); n ? to_a.last(n) : self.end; end
  def entries; to_a; end
  def hash; [self.begin, self.end, self.exclude_end?].hash; end
end
