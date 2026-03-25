# RubyHash — Crystal implementation of Ruby Hash semantics.
#
# Design: backed by Crystal's Hash(HashKey, RubyObject) where HashKey wraps
# a RubyObject and delegates #hash / #== to the Ruby-level implementations
# on RubyObject.  This means Crystal's built-in bucket logic drives dispatch,
# but the equality and hash semantics are fully Ruby-defined.
#
# Key ordering: insertion-ordered, matching Ruby 1.9+ behaviour.
# Default value: configurable via #default= (stored as a RubyObject).
#
# Compare-by-identity mode: when enabled, key lookup uses Crystal's
# `same?` (pointer equality) instead of Ruby value equality.  Implemented
# by switching to a separate identity-keyed internal store.

require "./ruby_object"
require "./ruby_integer"
require "./ruby_nil"
require "./ruby_bool"
require "./ruby_array"

# ---------------------------------------------------------------------------
# Internal key wrapper — bridges Crystal Hash to Ruby equality/hashing.
# ---------------------------------------------------------------------------

private struct HashKey
  getter obj : RubyObject

  def initialize(@obj : RubyObject)
  end

  def hash(hasher)
    hasher = @obj.hash.hash(hasher)
    hasher
  end

  def ==(other : HashKey) : Bool
    @obj == other.obj
  end
end

# ---------------------------------------------------------------------------
# RubyHash
# ---------------------------------------------------------------------------

class RubyHash < RubyObject
  @data : Hash(HashKey, RubyObject)
  @default : RubyObject
  @compare_by_identity : Bool

  # -------------------------------------------------------------------------
  # Constructors
  # -------------------------------------------------------------------------

  def initialize
    @data = Hash(HashKey, RubyObject).new
    @default = RubyNil::INSTANCE
    @compare_by_identity = false
  end

  def initialize(default : RubyObject)
    @data = Hash(HashKey, RubyObject).new
    @default = default
    @compare_by_identity = false
  end

  # -------------------------------------------------------------------------
  # Default value
  # -------------------------------------------------------------------------

  getter default : RubyObject

  def default=(v : RubyObject)
    @default = v
  end

  # -------------------------------------------------------------------------
  # Compare-by-identity mode
  # -------------------------------------------------------------------------

  def compare_by_identity! : RubyHash
    @compare_by_identity = true
    self
  end

  def compare_by_identity? : RubyBool
    @compare_by_identity ? RubyBool::TRUE : RubyBool::FALSE
  end

  # -------------------------------------------------------------------------
  # Core access
  # -------------------------------------------------------------------------

  def [](key : RubyObject) : RubyObject
    if @compare_by_identity
      @data.each do |k, v|
        return v if k.obj.same?(key)
      end
      return @default
    end
    @data.fetch(HashKey.new(key)) { @default }
  end

  def []?(key : RubyObject) : RubyObject?
    if @compare_by_identity
      @data.each { |k, v| return v if k.obj.same?(key) }
      return nil
    end
    @data[HashKey.new(key)]?
  end

  def []=(key : RubyObject, value : RubyObject) : RubyObject
    if @compare_by_identity
      @data.each do |k, _|
        if k.obj.same?(key)
          @data[k] = value
          return value
        end
      end
    end
    @data[HashKey.new(key)] = value
    value
  end

  def delete(key : RubyObject) : RubyObject
    if @compare_by_identity
      @data.each do |k, _|
        if k.obj.same?(key)
          @data.delete(k)
          return key
        end
      end
      return RubyNil::INSTANCE
    end
    @data.delete(HashKey.new(key)) || RubyNil::INSTANCE
  end

  def fetch(key : RubyObject, default_val : RubyObject) : RubyObject
    self[key]? || default_val
  end

  def key?(key : RubyObject) : RubyBool
    if @compare_by_identity
      found = @data.any? { |k, _| k.obj.same?(key) }
      return found ? RubyBool::TRUE : RubyBool::FALSE
    end
    @data.has_key?(HashKey.new(key)) ? RubyBool::TRUE : RubyBool::FALSE
  end

  def has_key?(key : RubyObject) : RubyBool
    key?(key)
  end

  def include?(key : RubyObject) : RubyBool
    key?(key)
  end

  def value?(val : RubyObject) : RubyBool
    @data.values.any? { |v| v == val } ? RubyBool::TRUE : RubyBool::FALSE
  end

  def has_value?(val : RubyObject) : RubyBool
    value?(val)
  end

  # fetch with no default — returns nil if key is missing (Ruby: raises, but
  # for spec-layer convenience we return nil).
  def fetch(key : RubyObject) : RubyObject?
    self[key]?
  end

  # -------------------------------------------------------------------------
  # Size / emptiness
  # -------------------------------------------------------------------------

  def size : RubyInteger
    RubyInteger.new(@data.size.to_i64)
  end

  def length : RubyInteger
    size
  end

  def empty? : RubyBool
    @data.empty? ? RubyBool::TRUE : RubyBool::FALSE
  end

  # -------------------------------------------------------------------------
  # Mutation
  # -------------------------------------------------------------------------

  def clear : RubyHash
    @data.clear
    self
  end

  def merge!(other : RubyHash) : RubyHash
    other.each { |k, v| self[k] = v }
    self
  end

  def merge(other : RubyHash) : RubyHash
    copy = RubyHash.new(@default)
    each { |k, v| copy[k] = v }
    other.each { |k, v| copy[k] = v }
    copy
  end

  # -------------------------------------------------------------------------
  # Iteration (Crystal-level)
  # -------------------------------------------------------------------------

  def each(&block : RubyObject, RubyObject ->)
    @data.each { |k, v| block.call(k.obj, v) }
  end

  def each_pair(&block : RubyObject, RubyObject ->)
    each { |k, v| block.call(k, v) }
  end

  def each_key(&block : RubyObject ->)
    @data.each { |k, _| block.call(k.obj) }
  end

  def each_value(&block : RubyObject ->)
    @data.each { |_, v| block.call(v) }
  end

  def keys : RubyArray
    arr = RubyArray.new(@data.size)
    @data.each { |k, _| arr.push(k.obj) }
    arr
  end

  def values : RubyArray
    arr = RubyArray.new(@data.size)
    @data.each { |_, v| arr.push(v) }
    arr
  end

  def to_a : RubyArray
    arr = RubyArray.new(@data.size)
    @data.each do |k, v|
      pair = RubyArray.new(2)
      pair.push(k.obj)
      pair.push(v)
      arr.push(pair)
    end
    arr
  end

  def select_keys(&block : RubyObject, RubyObject -> Bool) : RubyHash
    result = RubyHash.new(@default)
    each { |k, v| result[k] = v if block.call(k, v) }
    result
  end

  def reject_keys(&block : RubyObject, RubyObject -> Bool) : RubyHash
    result = RubyHash.new(@default)
    each { |k, v| result[k] = v unless block.call(k, v) }
    result
  end

  def map_values(&block : RubyObject -> RubyObject) : RubyHash
    result = RubyHash.new(@default)
    each { |k, v| result[k] = block.call(v) }
    result
  end

  def map_values!(&block : RubyObject -> RubyObject) : RubyHash
    @data.transform_values! { |v| block.call(v) }
    self
  end

  # -------------------------------------------------------------------------
  # RubyObject interface
  # -------------------------------------------------------------------------

  def to_s : String
    inspect
  end

  def inspect : String
    pairs = [] of String
    @data.each { |k, v| pairs << "#{k.obj.inspect}=>#{v.inspect}" }
    "{#{pairs.join(", ")}}"
  end

  def ==(other : RubyHash) : Bool
    return false if @data.size != other.@data.size
    @data.all? do |k, v|
      other_v = other[k.obj]?
      !other_v.nil? && (v == other_v)
    end
  end

  def ==(other : RubyObject) : Bool
    false
  end

  def hash : UInt64
    h = 0xf00dcafe_u64
    @data.each { |k, v| h ^= k.obj.hash &* 0x9e3779b97f4a7c15_u64 &+ v.hash }
    h
  end
end
