class Hash
  def hash = Intrinsics.hash_hash(self)
  def eql?(v) = Intrinsics.hash_eql(self, v)
  def [](key) = Intrinsics.hash_index(self, key)
end
