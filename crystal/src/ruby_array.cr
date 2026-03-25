# RubyArray — Crystal implementation of Ruby Array semantics.
#
# Design: a mutable, ordered collection of RubyObject references.
# Backed by Crystal's Array(RubyObject) for O(1) indexed access and
# amortised-O(1) push/pop.  Shift/unshift are O(n) — acceptable for now;
# a ring-buffer optimisation can come later if benchmarks demand it.
#
# Hash/equality:
#   Two arrays are equal when they have the same length and each pair of
#   elements is equal (recursively).  The hash is a fold over element hashes
#   so that equal arrays produce the same bucket in a Hash(RubyObject,…).

require "./ruby_object"
require "./ruby_integer"
require "./ruby_nil"
require "./ruby_bool"

class RubyArray < RubyObject
  getter data : Array(RubyObject)

  # -------------------------------------------------------------------------
  # Constructors
  # -------------------------------------------------------------------------

  def initialize
    @data = [] of RubyObject
  end

  def initialize(capacity : Int)
    @data = Array(RubyObject).new(capacity)
  end

  def initialize(@data : Array(RubyObject))
  end

  # -------------------------------------------------------------------------
  # Length / emptiness
  # -------------------------------------------------------------------------

  def length : RubyInteger
    RubyInteger.new(@data.size.to_i64)
  end

  def size : RubyInteger
    length
  end

  def empty? : RubyBool
    @data.empty? ? RubyBool::TRUE : RubyBool::FALSE
  end

  # -------------------------------------------------------------------------
  # Element access
  # -------------------------------------------------------------------------

  # arr[i] — supports negative indices (wraps from end).  Returns RubyNil
  # when out of bounds, matching Ruby semantics.
  def [](i : Int64) : RubyObject
    idx = i < 0 ? @data.size + i : i
    return RubyNil::INSTANCE if idx < 0 || idx >= @data.size
    @data[idx]
  end

  def [](i : RubyInteger) : RubyObject
    self[i.to_i64]
  end

  # arr[i] = v — extends with nil if i > size (Ruby semantics).
  def []=(i : Int64, v : RubyObject) : RubyObject
    idx = i < 0 ? @data.size + i : i
    raise IndexError.new("index #{i} too small for array; minimum: #{-@data.size}") if idx < 0
    while @data.size <= idx
      @data << RubyNil::INSTANCE
    end
    @data[idx] = v
    v
  end

  def []=(i : RubyInteger, v : RubyObject) : RubyObject
    self[i.to_i64] = v
  end

  # -------------------------------------------------------------------------
  # Mutating operations
  # -------------------------------------------------------------------------

  # Accept Int32 index as well as Int64 and RubyInteger.
  def [](i : Int32) : RubyObject
    self[i.to_i64]
  end

  def []=(i : Int32, v : RubyObject) : RubyObject
    self[i.to_i64] = v
  end

  def push(v : RubyObject) : RubyArray
    @data << v
    self
  end

  def <<(v : RubyObject) : RubyArray
    push(v)
  end

  def pop : RubyObject
    return RubyNil::INSTANCE if @data.empty?
    @data.pop
  end

  def shift : RubyObject
    return RubyNil::INSTANCE if @data.empty?
    @data.shift
  end

  def unshift(v : RubyObject) : RubyArray
    @data.unshift(v)
    self
  end

  def concat(other : RubyArray) : RubyArray
    @data.concat(other.data)
    self
  end

  def clear : RubyArray
    @data.clear
    self
  end

  # -------------------------------------------------------------------------
  # Non-mutating operations
  # -------------------------------------------------------------------------

  def +(other : RubyArray) : RubyArray
    RubyArray.new(@data + other.data)
  end

  def first : RubyObject
    @data.empty? ? RubyNil::INSTANCE : @data.first
  end

  def last : RubyObject
    @data.empty? ? RubyNil::INSTANCE : @data.last
  end

  def reverse : RubyArray
    RubyArray.new(@data.reverse)
  end

  def flatten : RubyArray
    result = RubyArray.new
    flatten_into(result)
    result
  end

  def flatten_into(acc : RubyArray)
    @data.each do |el|
      if el.is_a?(RubyArray)
        el.flatten_into(acc)
      else
        acc.push(el)
      end
    end
  end

  def include?(v : RubyObject) : RubyBool
    @data.any? { |el| el == v } ? RubyBool::TRUE : RubyBool::FALSE
  end

  def uniq : RubyArray
    seen = Hash(UInt64, Array(RubyObject)).new
    result = RubyArray.new
    @data.each do |el|
      bucket = seen[el.hash] ||= [] of RubyObject
      next if bucket.any? { |x| x == el }
      bucket << el
      result.push(el)
    end
    result
  end

  # -------------------------------------------------------------------------
  # Iteration helpers (Crystal-level, for use in specs / implementation)
  # -------------------------------------------------------------------------

  def each(&block : RubyObject ->)
    @data.each { |el| block.call(el) }
  end

  def each_with_index(&block : RubyObject, Int32 ->)
    @data.each_with_index { |el, i| block.call(el, i) }
  end

  def map(&block : RubyObject -> RubyObject) : RubyArray
    RubyArray.new(@data.map { |el| block.call(el) })
  end

  def select(&block : RubyObject -> Bool) : RubyArray
    RubyArray.new(@data.select { |el| block.call(el) })
  end

  def reject(&block : RubyObject -> Bool) : RubyArray
    RubyArray.new(@data.reject { |el| block.call(el) })
  end

  def compact : RubyArray
    RubyArray.new(@data.reject { |el| el.ruby_nil? })
  end

  def zip(other : RubyArray) : RubyArray
    result = [] of RubyObject
    sz = @data.size
    sz.times do |i|
      pair_data = [self[i.to_i64], other[i.to_i64]] of RubyObject
      result << RubyArray.new(pair_data)
    end
    RubyArray.new(result)
  end

  # -------------------------------------------------------------------------
  # RubyObject interface
  # -------------------------------------------------------------------------

  def to_s : String
    inspect
  end

  def inspect : String
    inner = @data.map(&.inspect).join(", ")
    "[#{inner}]"
  end

  def ==(other : RubyArray) : Bool
    return false if @data.size != other.data.size
    @data.zip(other.data).all? { |a, b| a == b }
  end

  def ==(other : RubyObject) : Bool
    false
  end

  def hash : UInt64
    h = 0xdeadbeef_u64
    @data.each { |el| h = h &* 31 &+ el.hash }
    h
  end
end
