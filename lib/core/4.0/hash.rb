class Hash
  def self.new(*args, capacity: nil, &block)
    if self.equal?(Hash)
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0..1)" if args.size > 1
      raise ArgumentError, "wrong number of arguments (given 1, expected 0)" if args.size == 1 && block
      Intrinsics.hash_new(args.size == 1 ? args[0] : nil, block)
    else
      h = allocate
      h.send(:initialize, *args, &block)
      h
    end
  end

  def initialize(default = nil, &block)
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    if block
      Intrinsics.hash_set_default_proc(self, block)
    else
      Intrinsics.hash_set_default(self, default)
    end
    self
  end

  def self.[](*args)
    h = allocate
    if args.length == 1
      arg = args[0]
      if arg.is_a?(Hash)
        arg.each { |k, v| h[k] = v }
        return h
      elsif arg.respond_to?(:to_hash)
        converted = arg.to_hash
        raise TypeError, "can't convert #{arg.class} into Hash (#{arg.class}#to_hash gives #{converted.class})" unless converted.is_a?(Hash)
        converted.each { |k, v| h[k] = v }
        return h
      elsif arg.respond_to?(:to_ary)
        idx = 0
        arg.to_ary.each do |pair|
          type_name = pair.nil? ? "nil" : (pair.equal?(true) ? "true" : (pair.equal?(false) ? "false" : pair.class.to_s))
          raise ArgumentError, "wrong element type #{type_name} at #{idx} (expected array)" unless pair.respond_to?(:to_ary)
          kv = pair.to_ary
          raise ArgumentError, "invalid number of elements (#{kv.length} for 1..2)" unless kv.length == 1 || kv.length == 2
          h[kv[0]] = kv.length == 2 ? kv[1] : nil
          idx += 1
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
    raise TypeError, "can't convert #{obj.class} into Hash (#{obj.class}#to_hash gives #{result.class})" unless result.nil? || result.is_a?(Hash)
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

  def default(key = :__no_key__)
    if default_proc
      return nil if key.equal?(:__no_key__)
      default_proc.call(self, key)
    else
      Intrinsics.hash_get_default(self, nil)
    end
  end

  def default=(val)
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    Intrinsics.hash_set_default(self, val)
  end
  def default_proc = Intrinsics.hash_get_default_proc(self)

  def default_proc=(prc)
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    if !prc.nil? && !prc.is_a?(Proc)
      raise TypeError, "#{prc.class} is not a Proc" unless prc.respond_to?(:to_proc)
      prc = prc.to_proc
    end
    if prc && prc.lambda? && prc.arity != 2
      raise TypeError, "default_proc takes two arguments (2 for #{prc.arity})"
    end
    Intrinsics.hash_set_default_proc(self, prc)
  end
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
  alias entries to_a
  def to_proc; h = self; ->(k) { h[k] }; end

  def to_hash = self

  def to_h(&block)
    unless block
      return self if instance_of?(Hash)
      r = {}
      each { |k, v| r[k] = v }
      r.compare_by_identity if compare_by_identity?
      if default_proc
        r.default_proc = default_proc
      elsif default
        r.default = default
      end
      return r
    end
    r = {}
    each do |k, v|
      pair = block.call(k, v)
      pair = pair.to_ary if !pair.is_a?(Array) && pair.respond_to?(:to_ary)
      raise TypeError, "wrong element type #{pair.class} (expected Array)" unless pair.is_a?(Array)
      raise ArgumentError, "element has wrong array length (expected 2, was #{pair.length})" unless pair.length == 2
      r[pair[0]] = pair[1]
    end
    r
  end

  def deconstruct_keys(keys) = self

  def to_s
    ongoing = (Fiber[:__hash_inspect__] ||= [])
    return '{...}' if ongoing.include?(__id__)
    ongoing << __id__
    begin
      pairs = []
      each do |k, v|
        v_s = v.inspect
        unless v_s.is_a?(String)
          v_s2 = v_s.to_s
          v_s = v_s2.is_a?(String) ? v_s2 : "#<#{v_s.class.name}:0x#{v_s.__id__.to_s(16)}>"
        end
        if k.is_a?(Symbol)
          name = k.to_s
          # Use bare-word syntax only for simple identifiers (letters/digits/underscore,
          # optional ?/! suffix). Everything else (operators, setters, etc.) needs quoting.
          if name =~ /\A[a-zA-Z_\u0080-\uFFFF][a-zA-Z0-9_\u0080-\uFFFF]*[?!]?\z/
            pairs << "#{name}: #{v_s}"
          else
            pairs << "#{name.inspect}: #{v_s}"
          end
        else
          k_s = k.inspect
          unless k_s.is_a?(String)
            k_s2 = k_s.to_s
            k_s = k_s2.is_a?(String) ? k_s2 : "#<#{k_s.class.name}:0x#{k_s.__id__.to_s(16)}>"
          end
          pairs << "#{k_s} => #{v_s}"
        end
      end
      "{#{pairs.join(', ')}}"
    ensure
      ongoing.pop
    end
  end

  alias inspect to_s
  def dup
    r = self.class.allocate
    r.compare_by_identity if compare_by_identity?
    each { |k, v| r[k] = v }
    if default_proc
      r.default_proc = default_proc
    elsif default
      r.default = default
    end
    instance_variables.each { |iv| r.instance_variable_set(iv, instance_variable_get(iv)) }
    r
  end

  def clone(freeze: nil)
    r = dup
    r.freeze if freeze || (freeze.nil? && frozen?)
    r
  end

  def each(&block)
    return to_enum(:each) { size } unless block
    Intrinsics.hash_each(self, block)
  end
  alias each_pair each
  def each_key(&block)
    return to_enum(:each_key) { size } unless block
    each { |k, _| block.call(k) }
    self
  end

  def each_value(&block)
    return to_enum(:each_value) { size } unless block
    each { |_, v| block.call(v) }
    self
  end

  def each_with_object(obj)
    each { |k, v| yield([k, v], obj) }
    obj
  end

  def merge(*others, &block)
    r = dup
    others.each do |other|
      other = other.to_hash if !other.is_a?(Hash) && other.respond_to?(:to_hash)
      raise TypeError, "no implicit conversion of #{other.class} into Hash" unless other.is_a?(Hash)
      if block
        other.each { |k, v| r[k] = r.key?(k) ? block.call(k, r[k], v) : v }
      else
        other.each { |k, v| r[k] = v }
      end
    end
    r
  end

  def merge!(*others, &block)
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    others.each do |other|
      other = other.to_hash if !other.is_a?(Hash) && other.respond_to?(:to_hash)
      raise TypeError, "no implicit conversion of #{other.class} into Hash" unless other.is_a?(Hash)
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
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    other = other.to_hash if !other.is_a?(Hash) && other.respond_to?(:to_hash)
    raise TypeError, "no implicit conversion of #{other.class} into Hash" unless other.is_a?(Hash)
    Intrinsics.hash_clear(self)
    Intrinsics.hash_reset_compare_by_identity(self)
    other.each { |k, v| self[k] = v }
    if other.default_proc
      Intrinsics.hash_set_default_proc(self, other.default_proc)
    else
      Intrinsics.hash_set_default(self, other.default)
    end
    compare_by_identity if other.compare_by_identity?
    self
  end

  def delete(key, &block)
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    return Intrinsics.hash_delete(self, key) if key?(key)
    block ? block.call(key) : nil
  end

  def delete_if(&block)
    return to_enum(:delete_if) { size } unless block
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    each { |k, v| Intrinsics.hash_delete(self, k) if block.call(k, v) }
    self
  end

  def keep_if(&block)
    return to_enum(:keep_if) { size } unless block
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    each { |k, v| Intrinsics.hash_delete(self, k) unless block.call(k, v) }
    self
  end

  def fetch(key, *args, &block)
    raise ArgumentError, "wrong number of arguments (given #{args.length + 1}, expected 1..2)" if args.length > 1
    return self[key] if key?(key)
    if block
      warn "warning: block supersedes default value argument" unless args.empty?
      return block.call(key)
    end
    return args[0] unless args.empty?
    raise KeyError.new("key not found: #{key.inspect}", receiver: self, key: key)
  end

  def fetch_values(*keys, &block)
    keys.map { |k| key?(k) ? self[k] : (block ? block.call(k) : raise(KeyError.new("key not found: #{k.inspect}", receiver: self, key: k))) }
  end

  def dig(key, *rest)
    val = self[key]
    return val if rest.empty? || val.nil?
    val.dig(*rest)
  end

  def select(&block)
    return to_enum(:select) { size } unless block
    r = self.class.allocate
    r.compare_by_identity if compare_by_identity?
    each { |k, v| r[k] = v if block.call(k, v) }
    r
  end

  alias filter select

  def select!(&block)
    return to_enum(:select!) { size } unless block
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    changed = false
    each { |k, v| unless block.call(k, v); Intrinsics.hash_delete(self, k); changed = true; end }
    changed ? self : nil
  end

  alias filter! select!

  def reject(&block)
    return to_enum(:reject) { size } unless block
    r = self.class.allocate
    r.compare_by_identity if compare_by_identity?
    each { |k, v| r[k] = v unless block.call(k, v) }
    r
  end

  def reject!(&block)
    return to_enum(:reject!) { size } unless block
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    changed = false
    each { |k, v| if block.call(k, v); Intrinsics.hash_delete(self, k); changed = true; end }
    changed ? self : nil
  end

  def map(&block)
    return to_enum(:map) { size } unless block
    r = []
    if block.arity == 1
      each { |k, v| r << block.call([k, v]) }
    else
      each { |k, v| r << block.call(k, v) }
    end
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

  def transform_keys(hash = nil, &block)
    return to_enum(:transform_keys) { size } if hash.nil? && !block
    r = {}
    each do |k, v|
      nk = if hash && hash.key?(k)
        hash[k]
      elsif block
        block.call(k)
      else
        k
      end
      r[nk] = v
    end
    r
  end

  def transform_keys!(hash = nil, &block)
    return to_enum(:transform_keys!) { size } if hash.nil? && !block
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    Intrinsics.hash_transform_keys_bang(self, hash, block)
  end

  def transform_values(&block)
    return to_enum(:transform_values) { size } unless block
    r = {}
    r.compare_by_identity if compare_by_identity?
    each { |k, v| r[k] = block.call(v) }
    r
  end

  def transform_values!(&block)
    return to_enum(:transform_values!) { size } unless block
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    each { |k, v| self[k] = block.call(v) }
    self
  end

  def invert
    r = {}
    each { |k, v| r[v] = k }
    r
  end

  def flatten(depth = 1)
    depth = depth.respond_to?(:to_int) ? depth.to_int : depth
    raise TypeError, "no implicit conversion of #{depth.class} into Integer" unless depth.is_a?(Integer)
    to_a.flatten(depth)
  end

  def shift
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    return nil if empty?
    k = keys.first
    v = Intrinsics.hash_delete(self, k)
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
    r = Hash.new
    r.compare_by_identity if compare_by_identity?
    keys.each { |k| r[k] = Intrinsics.hash_index(self, k) if key?(k) }
    r
  end

  def except(*keys)
    r = self.class.allocate
    r.compare_by_identity if compare_by_identity?
    each { |k, v| r[k] = v unless keys.include?(k) }
    r
  end

  def any?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |k, v| return true if (block ? block.call(k, v) : true) }
    else
      warn "warning: given block not used" if block
      each { |k, v| return true if pat === [k, v] }
    end
    false
  end

  def all?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |k, v| return false unless (block ? block.call(k, v) : true) }
    else
      warn "warning: given block not used" if block
      each { |k, v| return false unless pat === [k, v] }
    end
    true
  end

  def none?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |k, v| return false if (block ? block.call(k, v) : true) }
    else
      warn "warning: given block not used" if block
      each { |k, v| return false if pat === [k, v] }
    end
    true
  end

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


  def compare_by_identity = Intrinsics.hash_compare_by_identity(self)
  def compare_by_identity? = Intrinsics.hash_compare_by_identity_q(self)

  def clear
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    Intrinsics.hash_clear(self)
  end

  def compact
    r = self.class.allocate
    r.compare_by_identity if compare_by_identity?
    each { |k, v| r[k] = v unless v.nil? }
    if default_proc
      r.default_proc = default_proc
    else
      r.default = default
    end
    r
  end

  def compact!
    changed = false
    each { |k, v| if v.nil?; delete(k); changed = true; end }
    changed ? self : nil
  end

  def rehash
    raise FrozenError, "can't modify frozen Hash: #{inspect}" if frozen?
    pairs = map { |k, v| [k, v] }
    Intrinsics.hash_clear(self)
    pairs.each { |k, v| self[k] = v }
    self
  end

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
    other = other.to_hash if !other.is_a?(Hash) && other.respond_to?(:to_hash)
    raise TypeError, "no implicit conversion of #{other.class} into Hash" unless other.is_a?(Hash)
    each { |k, v| return false unless other.key?(k) && other[k] == v }
    true
  end

  def >=(other)
    other = other.to_hash if !other.is_a?(Hash) && other.respond_to?(:to_hash)
    raise TypeError, "no implicit conversion of #{other.class} into Hash" unless other.is_a?(Hash)
    other <= self
  end

  def <(other)
    other = other.to_hash if !other.is_a?(Hash) && other.respond_to?(:to_hash)
    raise TypeError, "no implicit conversion of #{other.class} into Hash" unless other.is_a?(Hash)
    self <= other && self != other
  end

  def >(other)
    other = other.to_hash if !other.is_a?(Hash) && other.respond_to?(:to_hash)
    raise TypeError, "no implicit conversion of #{other.class} into Hash" unless other.is_a?(Hash)
    self >= other && self != other
  end

  def hash
    ongoing = (Fiber[:__hash_hash__] ||= [])
    return 0 if ongoing.include?(__id__)
    ongoing << __id__
    begin
      acc = size.hash
      each { |k, v| acc = acc ^ (k.hash * 31 + v.hash) }
      acc
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

  def self.ruby2_keywords_hash(h)
    raise TypeError, "not a hash" unless h.is_a?(Hash)
    r = h.dup
    Intrinsics.hash_ruby2_keywords_hash(r)
    r
  end

  def self.ruby2_keywords_hash?(h)
    raise TypeError, "not a hash" unless h.is_a?(Hash)
    Intrinsics.hash_ruby2_keywords_hash_q(h)
  end
end
