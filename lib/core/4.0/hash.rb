class Hash
  def self.new(default = nil, &block)
    Intrinsics.hash_new(default, block)
  end
  def ==(other) = Intrinsics.hash_eq(self, other)
  def [](key) = Intrinsics.hash_index(self, key)
  def []=(key, value) = Intrinsics.hash_index_write(self, key, value)
  def size = Intrinsics.hash_size(self)
  alias length size
  def empty? = Intrinsics.hash_empty(self)
  def key?(key) = Intrinsics.hash_key(self, key)
  alias has_key? key?
  alias include? key?
  alias member? key?
  def value?(v) = Intrinsics.hash_value(self, v)
  alias has_value? value?
  def keys = Intrinsics.hash_keys(self)
  def values = Intrinsics.hash_values(self)
  def to_a = Intrinsics.hash_to_a(self)
  def to_s = Intrinsics.hash_to_s(self)
  alias inspect to_s
  def dup = Intrinsics.hash_dup(self)
  def freeze = Intrinsics.hash_freeze(self)
  def frozen? = Intrinsics.hash_frozen(self)

  def each(&block) = Intrinsics.hash_each(self, block)
  alias each_pair each
  def each_key(&block) = Intrinsics.hash_each_key(self, block)
  def each_value(&block) = Intrinsics.hash_each_value(self, block)

  def merge(other) = Intrinsics.hash_merge(self, other)
  def merge!(other) = Intrinsics.hash_update(self, other)
  alias update merge!
  def delete(key) = Intrinsics.hash_delete(self, key)
  def fetch(key, default = nil) = Intrinsics.hash_fetch(self, key, default)

  def select(&block) = Intrinsics.hash_select(self, block)
  alias filter select
  def reject(&block) = Intrinsics.hash_reject(self, block)
  def map(&block) = Intrinsics.hash_map(self, block)
  def any?(&block) = Intrinsics.hash_any(self, block)
  def all?(&block) = Intrinsics.hash_all(self, block)
  def none?(&block) = Intrinsics.hash_none(self, block)
  def count(&block) = Intrinsics.hash_count(self, block)

  def hash = Intrinsics.hash_hash(self)
  def eql?(v) = Intrinsics.hash_eql(self, v)
end
