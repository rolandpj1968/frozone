class Array
  def hash = Intrinsics.array_hash(self)
  def eql?(v) = Intrinsics.array_eql(self, v)
end
