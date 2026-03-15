class Hash
  def self.new(default = nil, &block)
    Intrinsics.hash_new(default, block)
  end

  def self.[](*args)
    h = {}
    if args.length == 1
      arg = args[0]
      if arg.is_a?(Hash)
        arg.each { |k, v| h[k] = v }
        return h
      elsif arg.respond_to?(:to_ary)
        arg.to_ary.each do |pair|
          raise ArgumentError, "wrong element type #{pair.class} at 0 (expected Array)" unless pair.respond_to?(:to_ary)
          kv = pair.to_ary
          raise ArgumentError, "invalid number of elements (#{kv.length} for 1..2)" unless kv.length == 1 || kv.length == 2
          h[kv[0]] = kv.length == 2 ? kv[1] : nil
        end
        return h
      end
    end
    raise ArgumentError, "odd number of arguments for Hash" if args.length.odd?
    i = 0
    while i < args.length
      h[args[i]] = args[i + 1]
      i += 2
    end
    h
  end

  def self.try_convert(obj)
    return obj if obj.is_a?(Hash)
    return nil unless obj.respond_to?(:to_hash)
    result = obj.to_hash
    raise TypeError, "can't convert #{obj.class} into Hash" unless result.is_a?(Hash)
    result
  end

  def ==(other)
    return false unless other.is_a?(Hash)
    return false unless size == other.size
    return true if equal?(other)
    ongoing = (Fiber[:__hash_eq__] ||= [])
    id1, id2 = __id__, other.__id__
    return true if ongoing.any? { |a, b| a == id1 && b == id2 }
    ongoing << [id1, id2]
    begin
      each { |k, v| return false unless other.key?(k) && v == other[k] }
      true
    ensure
      ongoing.pop
    end
  end

  def [](key) = Intrinsics.hash_index(self, key)
  def []=(key, value) = Intrinsics.hash_index_write(self, key, value)
  alias store []=

  def default(key = nil) = Intrinsics.hash_get_default(self, key)
  def default=(val) = Intrinsics.hash_set_default(self, val)
  def default_proc = Intrinsics.hash_get_default_proc(self)
  def default_proc=(prc) = Intrinsics.hash_set_default_proc(self, prc)
  def size = Intrinsics.hash_size(self)
  alias length size
  def empty?; size == 0; end
  def key?(key) = Intrinsics.hash_key(self, key)
  alias has_key? key?
  alias include? key?
  alias member? key?
  def value?(v); each { |_, val| return true if val == v }; false; end
  alias has_value? value?
  def key(val); each { |k, v| return k if v == val }; nil; end
  alias index key
  def keys;   r = []; each { |k, _| r << k }; r; end
  def values; r = []; each { |_, v| r << v }; r; end
  def to_a;   r = []; each { |k, v| r << [k, v] }; r; end

  def to_h(&block)
    return self unless block
    r = {}
    each { |k, v| pair = block.call(k, v); r[pair[0]] = pair[1] }
    r
  end

  def to_s
    ongoing = (Fiber[:__hash_inspect__] ||= [])
    return '{...}' if ongoing.include?(__id__)
    ongoing << __id__
    begin
      pairs = []
      each { |k, v| pairs << "#{k.inspect}=>#{v.inspect}" }
      "{#{pairs.join(', ')}}"
    ensure
      ongoing.pop
    end
  end

  alias inspect to_s
  def dup; r = {}; each { |k, v| r[k] = v }; r; end
  def clone; dup; end

  def each(&block) = Intrinsics.hash_each(self, block)
  alias each_pair each
  def each_key(&block);   each { |k, _| block ? block.call(k) : yield(k) }; self; end
  def each_value(&block); each { |_, v| block ? block.call(v) : yield(v) }; self; end

  def each_with_object(obj)
    each { |k, v| yield([k, v], obj) }
    obj
  end

  def merge(*others, &block)
    r = dup
    others.each do |other|
      if block
        other.each { |k, v| r[k] = r.key?(k) ? block.call(k, r[k], v) : v }
      else
        other.each { |k, v| r[k] = v }
      end
    end
    r
  end

  def merge!(*others, &block)
    others.each do |other|
      if block
        other.each { |k, v| self[k] = self.key?(k) ? block.call(k, self[k], v) : v }
      else
        other.each { |k, v| self[k] = v }
      end
    end
    self
  end

  alias update merge!

  def replace(other)
    Intrinsics.hash_clear(self)
    other.each { |k, v| self[k] = v }
    self
  end

  def delete(key) = Intrinsics.hash_delete(self, key)

  def delete_if
    return to_enum(:delete_if) unless block_given?
    each { |k, v| delete(k) if yield(k, v) }
    self
  end

  def keep_if
    return to_enum(:keep_if) unless block_given?
    each { |k, v| delete(k) unless yield(k, v) }
    self
  end

  def fetch(key, *args, &block)
    return self[key] if key?(key)
    return block.call(key) if block
    return args[0] unless args.empty?
    raise KeyError, "key not found: #{key.inspect}"
  end

  def fetch_values(*keys, &block)
    keys.map { |k| key?(k) ? self[k] : (block ? block.call(k) : raise(KeyError, "key not found: #{k.inspect}")) }
  end

  def dig(key, *rest)
    val = self[key]
    return val if rest.empty? || val.nil?
    val.dig(*rest)
  end

  def select(&block)
    return to_enum(:select) unless block
    r = {}
    each { |k, v| r[k] = v if (block ? block.call(k, v) : yield(k, v)) }
    r
  end

  alias filter select

  def select!(&block)
    return to_enum(:select!) unless block
    changed = false
    each { |k, v| unless block.call(k, v); delete(k); changed = true; end }
    changed ? self : nil
  end

  alias filter! select!

  def reject(&block)
    return to_enum(:reject) unless block
    r = {}
    each { |k, v| r[k] = v unless (block ? block.call(k, v) : yield(k, v)) }
    r
  end

  def reject!(&block)
    return to_enum(:reject!) unless block
    changed = false
    each { |k, v| if block.call(k, v); delete(k); changed = true; end }
    changed ? self : nil
  end

  def map(&block)
    return to_enum(:map) unless block
    r = []
    each { |k, v| r << (block ? block.call(k, v) : yield(k, v)) }
    r
  end

  alias collect map

  def flat_map(&block)
    return to_enum(:flat_map) unless block
    r = []
    each { |k, v| result = block.call(k, v); result.is_a?(Array) ? r.concat(result) : r << result }
    r
  end

  alias collect_concat flat_map

  def transform_keys(&block)
    return to_enum(:transform_keys) unless block
    r = {}
    each { |k, v| r[block.call(k)] = v }
    r
  end

  def transform_keys!(&block)
    return to_enum(:transform_keys!) unless block
    keys.each { |k| nk = block.call(k); v = delete(k); self[nk] = v }
    self
  end

  def transform_values(&block)
    return to_enum(:transform_values) unless block
    r = {}
    each { |k, v| r[k] = block.call(v) }
    r
  end

  def transform_values!(&block)
    return to_enum(:transform_values!) unless block
    each { |k, v| self[k] = block.call(v) }
    self
  end

  def invert
    r = {}
    each { |k, v| r[v] = k }
    r
  end

  def flatten(depth = 1)
    to_a.flatten(depth)
  end

  def shift
    return nil if empty?
    k = keys.first
    v = delete(k)
    [k, v]
  end

  def assoc(obj)
    each { |k, v| return [k, v] if k == obj }
    nil
  end

  def rassoc(val)
    each { |k, v| return [k, v] if v == val }
    nil
  end

  def values_at(*keys)
    keys.map { |k| self[k] }
  end

  def slice(*keys)
    r = {}
    keys.each { |k| r[k] = self[k] if key?(k) }
    r
  end

  def except(*keys)
    r = dup
    keys.each { |k| r.delete(k) }
    r
  end

  def any?(&block);  each { |k, v| return true  if (block ? block.call(k, v) : yield(k, v)) }; false; end
  def all?(&block);  each { |k, v| return false unless (block ? block.call(k, v) : yield(k, v)) }; true; end
  def none?(&block); each { |k, v| return false if (block ? block.call(k, v) : yield(k, v)) }; true; end

  def count(&block)
    return size unless block
    n = 0; each { |k, v| n += 1 if (block ? block.call(k, v) : yield(k, v)) }; n
  end

  def min_by(&block)
    return to_enum(:min_by) unless block
    min = nil; min_val = nil
    each { |k, v| val = block.call(k, v); if min_val.nil? || val < min_val; min_val = val; min = [k, v]; end }
    min
  end

  def max_by(&block)
    return to_enum(:max_by) unless block
    max = nil; max_val = nil
    each { |k, v| val = block.call(k, v); if max_val.nil? || val > max_val; max_val = val; max = [k, v]; end }
    max
  end

  def sum(init = 0)
    result = init
    each { |k, v| result += block_given? ? yield(k, v) : v }
    result
  end

  def group_by
    return to_enum(:group_by) unless block_given?
    r = {}; each { |k, v| key = yield(k, v); r[key] ||= []; r[key] << [k, v] }; r
  end

  def find
    return to_enum(:find) unless block_given?
    each { |k, v| return [k, v] if yield(k, v) }
    nil
  end

  alias detect find

  def sort_by(&block)
    return to_enum(:sort_by) unless block
    to_a.sort_by { |kv| block.call(*kv) }
  end

  def reduce(init = nil, &block)
    acc = init
    each { |k, v| acc = acc.nil? ? [k, v] : block.call(acc, [k, v]) }
    acc
  end

  alias inject reduce

  def compare_by_identity = Intrinsics.hash_compare_by_identity(self)
  def compare_by_identity? = Intrinsics.hash_compare_by_identity_q(self)

  def clear = Intrinsics.hash_clear(self)

  def compact
    r = {}
    each { |k, v| r[k] = v unless v.nil? }
    r
  end

  def compact!
    changed = false
    each { |k, v| if v.nil?; delete(k); changed = true; end }
    changed ? self : nil
  end

  def rehash = self  # stub - not needed for value-based hash

  def sort(&block)
    to_a.sort(&block)
  end

  def find_all(&block)
    return to_enum(:find_all) unless block
    r = []
    each { |k, v| r << [k, v] if block.call(k, v) }
    r
  end

  def first(n = nil)
    return to_a.first(n) if n
    to_a.first
  end

  def take(n)
    to_a.take(n)
  end

  def <=(other)
    return false unless other.is_a?(Hash)
    each { |k, v| return false unless other.key?(k) && other[k] == v }
    true
  end

  def >=(other)
    return false unless other.is_a?(Hash)
    other <= self
  end

  def <(other)
    self <= other && self != other
  end

  def >(other)
    self >= other && self != other
  end

  def hash
    ongoing = (Fiber[:__hash_hash__] ||= [])
    return 0 if ongoing.include?(__id__)
    ongoing << __id__
    begin
      acc = 0; each { |k, v| acc = acc ^ (k.hash ^ v.hash) }; acc
    ensure
      ongoing.pop
    end
  end

  def eql?(other)
    return false unless other.is_a?(Hash)
    return false unless size == other.size
    return true if equal?(other)
    ongoing = (Fiber[:__hash_eql__] ||= [])
    id1, id2 = __id__, other.__id__
    return true if ongoing.any? { |a, b| a == id1 && b == id2 }
    ongoing << [id1, id2]
    begin
      each { |k, v| return false unless other.key?(k) && v.eql?(other[k]) }
      true
    ensure
      ongoing.pop
    end
  end

  def self.ruby2_keywords_hash(h) = Intrinsics.hash_ruby2_keywords_hash(h)
  def self.ruby2_keywords_hash?(h) = Intrinsics.hash_ruby2_keywords_hash_q(h)
end
