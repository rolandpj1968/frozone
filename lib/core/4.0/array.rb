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
end
