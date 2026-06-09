# ENV singleton object implementation for Frozone.
# ENV is a special singleton that wraps the process environment.
# It is not a Hash subclass, but it includes Enumerable and supports
# many Hash-like methods with proper key/value coercion and validation.
#
# Built entirely on four primitives:
#   Intrinsics.os_getenv(name)         -> String or nil
#   Intrinsics.os_setenv(name, value)  -> nil
#   Intrinsics.os_unsetenv(name)       -> nil
#   Intrinsics.os_environ_pairs        -> [[k, v], ...]

class ENVClass
  include Enumerable

  def to_s = "ENV"
  def inspect = to_hash.inspect
  def rehash = nil
  def empty? = Intrinsics.os_environ_pairs.empty?
  def size = Intrinsics.os_environ_pairs.size
  alias length size
  def keys = Intrinsics.os_environ_pairs.map { |pair| ENVClass.__enc(pair[0]) }
  def values = Intrinsics.os_environ_pairs.map { |pair| ENVClass.__enc(pair[1]) }
  def to_a = Intrinsics.os_environ_pairs.map { |pair| [ENVClass.__enc(pair[0]), ENVClass.__enc(pair[1])] }
  def key?(key) = !Intrinsics.os_getenv(ENVClass.__coerce_key(key)).nil?
  alias has_key? key?
  alias include? key?
  alias member? key?

  def ==(other)
    return to_hash == other.to_hash if other.is_a?(ENVClass)
    return to_hash == other if other.is_a?(Hash)
    false
  end

  def dup
    raise TypeError, "Cannot dup ENV, use ENV.to_h to get a copy of ENV as a hash"
  end

  def clone(freeze: true)
    unless freeze.nil? || freeze == true || freeze == false
      raise ArgumentError, "unexpected value for freeze: #{freeze.class}"
    end
    raise TypeError, "Cannot clone ENV, use ENV.to_h to get a copy of ENV as a hash"
  end

  def [](key)
    val = Intrinsics.os_getenv(ENVClass.__coerce_key(key))
    val.nil? ? nil : ENVClass.__enc(val)
  end

  def []=(key, value)
    if value.nil?
      begin
        key = ENVClass.__coerce_key(key)
        ENVClass.__validate_key(key)
      rescue TypeError, Errno::EINVAL
        return nil
      end
      Intrinsics.os_unsetenv(key)
      return nil
    end
    key = ENVClass.__coerce_key(key)
    value = ENVClass.__coerce_value(value)
    ENVClass.__validate_key(key)
    Intrinsics.os_setenv(key, value)
    value
  end
  alias store []=

  def delete(key, &block)
    key = ENVClass.__coerce_key(key)
    val = Intrinsics.os_getenv(key)
    if val.nil?
      block ? block.call(key) : nil
    else
      Intrinsics.os_unsetenv(key)
      ENVClass.__enc(val)
    end
  end

  def fetch(key, *args, &block)
    key = ENVClass.__coerce_key(key)
    warn "block supersedes default value argument" if block && args.size > 0
    val = Intrinsics.os_getenv(key)
    if val.nil?
      if block
        block.call(key)
      elsif args.size > 0
        args[0]
      else
        raise KeyError.new("key not found: #{key.inspect}", receiver: self, key: key)
      end
    else
      ENVClass.__enc(val)
    end
  end

  def value?(val)
    val = ENVClass.__soft_coerce_string__(val)
    return nil if val.nil?
    Intrinsics.os_environ_pairs.any? { |pair| pair[1] == val }
  end
  alias has_value? value?

  def each(&block)
    return to_enum(:each) { size } unless block
    Intrinsics.os_environ_pairs.each do |pair|
      block.call(ENVClass.__enc(pair[0]), ENVClass.__enc(pair[1]))
    end
    self
  end
  alias each_pair each

  def each_key(&block)
    return to_enum(:each_key) { size } unless block
    Intrinsics.os_environ_pairs.each { |pair| block.call(ENVClass.__enc(pair[0])) }
    self
  end

  def each_value(&block)
    return to_enum(:each_value) { size } unless block
    Intrinsics.os_environ_pairs.each { |pair| block.call(ENVClass.__enc(pair[1])) }
    self
  end

  def to_h(&block)
    return to_hash unless block
    {}.tap do |result|
      Intrinsics.os_environ_pairs.each do |pair|
        pair_result = block.call(ENVClass.__enc(pair[0]), ENVClass.__enc(pair[1]))
        unless pair_result.respond_to?(:to_ary)
          raise TypeError, "wrong element type #{pair_result.class} (expected Array)"
        end
        arr = pair_result.to_ary
        raise ArgumentError, "element has wrong array length (expected 2, was #{arr.length})" unless arr.length == 2
        result[arr[0]] = arr[1]
      end
    end
  end

  def to_hash = {}.tap { |h| Intrinsics.os_environ_pairs.each { |pair| h[ENVClass.__enc(pair[0])] = ENVClass.__enc(pair[1]) } }

  def assoc(key)
    key = ENVClass.__coerce_key(key)
    val = Intrinsics.os_getenv(key)
    val.nil? ? nil : [ENVClass.__enc(key), ENVClass.__enc(val)]
  end

  def rassoc(value)
    value = ENVClass.__soft_coerce_string__(value)
    return nil if value.nil?
    Intrinsics.os_environ_pairs.each do |pair|
      return [ENVClass.__enc(pair[0]), ENVClass.__enc(pair[1])] if pair[1] == value
    end
    nil
  end

  def key(value)
    value = ENVClass.__coerce_key(value)
    Intrinsics.os_environ_pairs.each do |pair|
      return ENVClass.__enc(pair[0]) if pair[1] == value
    end
    nil
  end

  def clear
    Intrinsics.os_environ_pairs.each { |pair| Intrinsics.os_unsetenv(pair[0]) }
    self
  end

  def replace(hash)
    raise TypeError, "no implicit conversion of #{hash.class} into Hash" unless hash.is_a?(Hash)
    validated = []
    hash.each do |k, v|
      k_str = ENVClass.__coerce_key(k)
      v_str = ENVClass.__coerce_value(v)
      ENVClass.__validate_key(k_str)
      validated << [k_str, v_str]
    end
    clear
    validated.each { |k_str, v_str| Intrinsics.os_setenv(k_str, v_str) }
    self
  end

  def update(*hashes, &block)
    hashes.each do |hash|
      hash.each do |k, v|
        k_str = ENVClass.__coerce_key(k)
        v_str = ENVClass.__coerce_value(v)
        ENVClass.__validate_key(k_str)
        if block
          old = Intrinsics.os_getenv(k_str)
          v_str = ENVClass.__coerce_value(block.call(k_str, ENVClass.__enc(old), ENVClass.__enc(v_str))) unless old.nil?
        end
        Intrinsics.os_setenv(k_str, v_str)
      end
    end
    self
  end
  alias merge! update

  def shift
    all = Intrinsics.os_environ_pairs
    return nil if all.empty?
    first = all[0]
    k = first[0]
    v = first[1]
    Intrinsics.os_unsetenv(k)
    [ENVClass.__enc(k), ENVClass.__enc(v)]
  end

  def slice(*keys)
    {}.tap do |result|
      keys.each do |key|
        k_str = ENVClass.__coerce_key(key)
        val = Intrinsics.os_getenv(k_str)
        result[key] = ENVClass.__enc(val) unless val.nil?
      end
    end
  end

  def except(*keys)
    excluded = keys.map { |k| ENVClass.__coerce_key(k) }
    {}.tap do |h|
      Intrinsics.os_environ_pairs.each do |pair|
        h[ENVClass.__enc(pair[0])] = ENVClass.__enc(pair[1]) unless excluded.include?(pair[0])
      end
    end
  end

  def values_at(*keys)
    keys.map do |key|
      val = Intrinsics.os_getenv(ENVClass.__coerce_key(key))
      val.nil? ? nil : ENVClass.__enc(val)
    end
  end

  def select(&block)
    return to_enum(:select) { size } unless block
    {}.tap { |h| each { |k, v| h[k] = v if block.call(k, v) } }
  end
  alias filter select

  def select!(&block)
    return to_enum(:select!) { size } unless block
    changed = false
    to_delete = []
    each { |k, v| to_delete << k unless block.call(k, v) }
    to_delete.each do |k|
      Intrinsics.os_unsetenv(k)
      changed = true
    end
    changed ? self : nil
  end
  alias filter! select!

  def reject(&block)
    return to_enum(:reject) { size } unless block
    {}.tap { |h| each { |k, v| h[k] = v unless block.call(k, v) } }
  end

  def reject!(&block)
    return to_enum(:reject!) { size } unless block
    changed = false
    to_delete = []
    each { |k, v| to_delete << k if block.call(k, v) }
    to_delete.each do |k|
      Intrinsics.os_unsetenv(k)
      changed = true
    end
    changed ? self : nil
  end

  def keep_if(&block)
    return to_enum(:keep_if) { size } unless block
    to_delete = []
    each { |k, v| to_delete << k unless block.call(k, v) }
    to_delete.each { |k| Intrinsics.os_unsetenv(k) }
    self
  end

  def delete_if(&block)
    return to_enum(:delete_if) { size } unless block
    to_delete = []
    each { |k, v| to_delete << k if block.call(k, v) }
    to_delete.each { |k| Intrinsics.os_unsetenv(k) }
    self
  end

  def invert = {}.tap { |h| each { |k, v| h[v] = k } }

  def merge(*hashes, &block)
    to_hash.tap do |result|
      hashes.each do |hash|
        hash.each do |k, v|
          result[k] = if block && result.key?(k)
            block.call(k, result[k], v)
          else
            v
          end
        end
      end
    end
  end

  class << self
    def __coerce_key(key) = __coerce_env_string__(key, :key)
    def __coerce_value(val) = __coerce_env_string__(val, :value)

    def __coerce_env_string__(val, role)
      return val if val.is_a?(String)
      unless val.respond_to?(:to_str)
        raise TypeError, "no implicit conversion of #{val.class} into String"
      end
      result = val.to_str
      raise TypeError, "no implicit conversion of #{result.class} into String" unless result.is_a?(String)
      result
    end

    def __validate_key(key)
      raise Errno::EINVAL, "Invalid argument - #{key}" if key.empty?
      raise Errno::EINVAL, "Invalid argument - #{key}" if key.include?('=')
    end

    def __enc(str)
      return str if str.nil?
      locale_enc = Encoding.find('locale')
      begin
        str = str.encode(locale_enc)
      rescue
        str = str.dup.force_encoding(locale_enc)
      end
      internal = Encoding.default_internal
      if internal
        begin
          str = str.encode(internal)
        rescue
          # leave as-is
        end
      end
      str
    end

    # Soft-coerce val to String via to_str; returns nil on failure (no raise).
    def __soft_coerce_string__(val)
      return val if val.is_a?(String)
      return nil unless val.respond_to?(:to_str)
      result = val.to_str
      result.is_a?(String) ? result : nil
    end
  end
end

ENV = ENVClass.new
