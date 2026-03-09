class Array
  def [](i) = Intrinsics.array_index(self, i)
  def []=(i, v) = Intrinsics.array_index_write(self, i, v)
  def push(v) = Intrinsics.array_push(self, v)
  alias << push
  def length = Intrinsics.array_length(self)
  alias size length
  def first = self[0]
  def last = self[self.length - 1]
  def to_s = Intrinsics.array_to_s(self)
  def inspect = to_s

  def hash = Intrinsics.array_hash(self)
  def eql?(v) = Intrinsics.array_eql(self, v)

  def each
    i = 0
    while i < length
      yield self[i]
      i += 1
    end
    self
  end

  def map;    r = []; each { |x| r << yield(x) };          r; end
  def select; r = []; each { |x| r << x if yield(x) };     r; end
  def reject; r = []; each { |x| r << x unless yield(x) }; r; end

  def each_with_index; i = 0; each { |x| yield x, i; i += 1 }; self; end

  def any?  = (each { |x| return true  if yield(x) }; false)
  def all?  = (each { |x| return false unless yield(x) }; true)
  def none? = (each { |x| return false if yield(x) }; true)

  def reduce(initial = nil); acc = initial; each { |x| acc = acc.nil? ? x : yield(acc, x) }; acc; end
  alias inject reduce
end
