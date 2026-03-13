class Hash
  def self.new(default = nil, &block)
    Intrinsics.hash_new(default, block)
  end

  def ==(other)
    return false unless other.is_a?(Hash)
    return false unless size == other.size
    each { |k, v| return false unless other.key?(k) && v == other[k] }
    true
  end

  def [](key) = Intrinsics.hash_index(self, key)
  def []=(key, value) = Intrinsics.hash_index_write(self, key, value)
  def size = Intrinsics.hash_size(self)
  alias length size
  def empty?; size == 0; end
  def key?(key) = Intrinsics.hash_key(self, key)
  alias has_key? key?
  alias include? key?
  alias member? key?
  def value?(v); each { |_, val| return true if val == v }; false; end
  alias has_value? value?
  def keys;   r = []; each { |k, _| r << k }; r; end
  def values; r = []; each { |_, v| r << v }; r; end
  def to_a;   r = []; each { |k, v| r << [k, v] }; r; end

  def to_s
    pairs = []
    each { |k, v| pairs << "#{k.inspect}=>#{v.inspect}" }
    "{#{pairs.join(', ')}}"
  end

  alias inspect to_s
  def dup; r = {}; each { |k, v| r[k] = v }; r; end

  def each(&block) = Intrinsics.hash_each(self, block)
  alias each_pair each
  def each_key(&block);   each { |k, _| block ? block.call(k) : yield(k) }; self; end
  def each_value(&block); each { |_, v| block ? block.call(v) : yield(v) }; self; end

  def merge(other);  r = dup; other.each { |k, v| r[k] = v }; r; end
  def merge!(other); other.each { |k, v| self[k] = v }; self; end
  alias update merge!
  def delete(key) = Intrinsics.hash_delete(self, key)

  def fetch(key, default = nil)
    return self[key] if key?(key)
    return default unless default.nil?
    raise KeyError, "key not found"
  end

  def select(&block)
    r = {}
    each { |k, v| r[k] = v if (block ? block.call(k, v) : yield(k, v)) }
    r
  end

  alias filter select

  def reject(&block)
    r = {}
    each { |k, v| r[k] = v unless (block ? block.call(k, v) : yield(k, v)) }
    r
  end

  def map(&block)
    r = []
    each { |k, v| r << (block ? block.call(k, v) : yield(k, v)) }
    r
  end

  def any?(&block);  each { |k, v| return true  if (block ? block.call(k, v) : yield(k, v)) }; false; end
  def all?(&block);  each { |k, v| return false unless (block ? block.call(k, v) : yield(k, v)) }; true; end
  def none?(&block); each { |k, v| return false if (block ? block.call(k, v) : yield(k, v)) }; true; end

  def count(&block)
    return size unless block
    n = 0; each { |k, v| n += 1 if (block ? block.call(k, v) : yield(k, v)) }; n
  end

  def hash; acc = 0; each { |k, v| acc = acc ^ (k.hash ^ v.hash) }; acc; end

  def eql?(other)
    return false unless other.is_a?(Hash)
    return false unless size == other.size
    each { |k, v| return false unless other.key?(k) && v.eql?(other[k]) }
    true
  end

  def self.ruby2_keywords_hash(h) = h
  def self.ruby2_keywords_hash?(h) = false
end
