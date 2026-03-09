class Hash
  def [](key) = Intrinsics.hash_index(self, key)
  def []=(key, value) = Intrinsics.hash_index_write(self, key, value)
  def size = Intrinsics.hash_size(self)
  alias length size
  def key?(key) = Intrinsics.hash_key(self, key)
  alias has_key? key?
  alias include? key?

  def hash = Intrinsics.hash_hash(self)
  def eql?(v) = Intrinsics.hash_eql(self, v)
end
