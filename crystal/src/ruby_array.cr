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

  def initialize(@data : Array(RubyObject))
  end

  # Array.new(count, default) — creates array of `count` copies of `default`
  def initialize(count : RubyObject, default : RubyObject)
    n = count.is_a?(RubyInteger) ? count.to_i64.to_i32 : 0
    @data = Array(RubyObject).new(n) { default }
  end
  def initialize(count : Int64, default : RubyObject)
    @data = Array(RubyObject).new(count.to_i32) { default }
  end

  def initialize(count : RubyObject)
    n = count.is_a?(RubyInteger) ? count.to_i64.to_i32 : 0
    @data = Array(RubyObject).new(n) { RubyNil::INSTANCE.as(RubyObject) }
  end

  # Array.new(count) { |i| block } — creates array of `count` elements from block.
  # Uses a manual loop (not Array.new { |i| }) to avoid Crystal inferring Int32 from
  # the internal iteration index and polluting closure-variable types in the block.
  def self.new(count : RubyObject, &block : RubyObject -> RubyObject) : RubyArray
    sz   = count.is_a?(RubyInteger) ? count.to_i64 : 0_i64
    data = [] of RubyObject
    idx  = 0_i64
    while idx < sz
      data << block.call(RubyInteger.new(idx))
      idx += 1_i64
    end
    RubyArray.new(data)
  end

  # Native-index overload: block receives Int64 directly (no boxing).
  # Used by AOT codegen when the block param is known to be a plain integer.
  def self.new(count : Int64, &block : Int64 -> RubyObject) : RubyArray
    data = Array(RubyObject).new(count.to_i32)
    count.times { |i| data << block.call(i) }
    RubyArray.new(data)
  end

  # Internal: allocate with a given Int32 capacity (not exposed as RubyArray.new(Int))
  protected def self.with_capacity(n : Int32) : RubyArray
    RubyArray.new(Array(RubyObject).new(n))
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

  def [](i : RubyObject) : RubyObject
    case i
    when RubyInteger then self[i.to_i64]
    else raise Exception.new("Array index must be Integer, got #{i.class}")
    end
  end

  def []=(i : RubyObject, v : RubyObject) : RubyObject
    case i
    when RubyInteger then self[i.to_i64] = v
    when RubyRange
      # a[range] = other_array — replace slice with other array's elements
      other = v.is_a?(RubyArray) ? v.as(RubyArray).data : [v]
      b = i.begin_val.to_i64
      e = i.end_val.to_i64
      b += @data.size if b < 0
      e += @data.size if e < 0
      e -= 1 if i.exclusive
      len = [e - b + 1, 0_i64].max
      @data[b.to_i32, len.to_i32] = other
      v
    else raise Exception.new("Array index must be Integer, got #{i.class}")
    end
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

  # Auto-boxing overloads: accept raw Int64/Float64 values
  def []=(i : Int64, v : Int64) : RubyObject
    self[i] = RubyInteger.new(v)
  end

  def []=(i : Int64, v : Float64) : RubyObject
    self[i] = RubyFloat.new(v)
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

  def delete_at(idx : RubyObject) : RubyObject
    i = idx.to_i64
    i += @data.size if i < 0
    return RubyNil::INSTANCE if i < 0 || i >= @data.size
    @data.delete_at(i)
  end

  def insert(idx : Int64, val : RubyObject) : RubyArray
    insert(RubyInteger.new(idx), val)
  end

  def insert(idx : RubyObject, val : RubyObject) : RubyArray
    i = idx.to_i64
    i += @data.size + 1 if i < 0
    @data.insert(i.to_i32, val)
    self
  end

  def fetch(idx : RubyObject) : RubyObject
    fetch(idx.to_i64)
  end

  def fetch(idx : Int64) : RubyObject
    i = idx
    i += @data.size if i < 0
    raise IndexError.new("index #{idx} outside of array bounds") if i < 0 || i >= @data.size
    @data[i]
  end

  def dup : RubyArray
    RubyArray.new(@data.dup)
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

  def first(n : RubyObject) : RubyArray
    cnt = n.is_a?(RubyInteger) ? n.to_i64.to_i32 : 0
    RubyArray.new(@data.first(cnt))
  end

  def last : RubyObject
    @data.empty? ? RubyNil::INSTANCE : @data.last
  end

  def last(n : RubyObject) : RubyArray
    cnt = n.is_a?(RubyInteger) ? n.to_i64.to_i32 : 0
    RubyArray.new(@data.last(cnt))
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

  def each_with_index(&block : RubyObject, RubyObject ->)
    @data.each_with_index { |el, i| block.call(el, RubyInteger.new(i.to_i64)) }
  end

  def map(&block : RubyObject -> RubyObject) : RubyArray
    RubyArray.new(@data.map { |el| block.call(el) })
  end

  # Array#transpose: rows[i][j] → result[j][i]. All rows must be RubyArrays
  # of the same length. Used by hoisted constant initialisers like
  # optcarrot's TILE_LUT.
  def transpose : RubyArray
    return RubyArray.new if @data.empty?
    rows = @data.map { |el| el.as(RubyArray).data }
    cols = rows.first.size
    result = Array(RubyObject).new(cols) do |j|
      RubyArray.new(rows.map { |row| row[j] }).as(RubyObject)
    end
    RubyArray.new(result)
  end

  def ruby_select(&block : RubyObject -> RubyObject) : RubyArray
    RubyArray.new(@data.select { |el| block.call(el).truthy? })
  end

  def reject(&block : RubyObject -> RubyObject) : RubyArray
    RubyArray.new(@data.reject { |el| block.call(el).truthy? })
  end

  def compact : RubyArray
    RubyArray.new(@data.reject { |el| el.ruby_nil? })
  end

  # Sort using Ruby <=> semantics (via RubyObject#<=>)
  def sort : RubyArray
    arr = @data.dup
    arr.sort! { |a, b| ruby_cmp(a, b) }
    RubyArray.new(arr)
  end

  def sort(&block : RubyObject, RubyObject -> RubyObject) : RubyArray
    arr = @data.dup
    arr.sort! { |a, b|
      cmp = block.call(a, b)
      cmp.is_a?(RubyInteger) ? cmp.to_i64.to_i32 : 0
    }
    RubyArray.new(arr)
  end

  def sort_by(&block : RubyObject -> RubyObject) : RubyArray
    arr = @data.dup
    arr.sort! { |a, b| ruby_cmp(block.call(a), block.call(b)) }
    RubyArray.new(arr)
  end

  def min : RubyObject
    return RubyNil::INSTANCE if @data.empty?
    best = @data[0]
    @data[1..].each { |el| best = el if ruby_cmp(el, best) < 0 }
    best
  end

  def max : RubyObject
    return RubyNil::INSTANCE if @data.empty?
    best = @data[0]
    @data[1..].each { |el| best = el if ruby_cmp(el, best) > 0 }
    best
  end

  def min_by(&block : RubyObject -> RubyObject) : RubyObject
    return RubyNil::INSTANCE if @data.empty?
    best = @data[0]; best_score = block.call(best)
    @data[1..].each do |el|
      score = block.call(el)
      if ruby_cmp(score, best_score) < 0
        best = el; best_score = score
      end
    end
    best
  end

  def max_by(&block : RubyObject -> RubyObject) : RubyObject
    return RubyNil::INSTANCE if @data.empty?
    best = @data[0]; best_score = block.call(best)
    @data[1..].each do |el|
      score = block.call(el)
      if ruby_cmp(score, best_score) > 0
        best = el; best_score = score
      end
    end
    best
  end

  # Blocks return RubyObject (RubyBool); .truthy? converts to Crystal Bool.
  def any?(&block : RubyObject -> RubyObject) : RubyBool
    @data.any? { |el| block.call(el).truthy? } ? RubyBool::TRUE : RubyBool::FALSE
  end

  def any? : RubyBool
    @data.any? { |el| el.truthy? } ? RubyBool::TRUE : RubyBool::FALSE
  end

  def all?(&block : RubyObject -> RubyObject) : RubyBool
    @data.all? { |el| block.call(el).truthy? } ? RubyBool::TRUE : RubyBool::FALSE
  end

  def all? : RubyBool
    @data.all? { |el| el.truthy? } ? RubyBool::TRUE : RubyBool::FALSE
  end

  def none?(&block : RubyObject -> RubyObject) : RubyBool
    @data.none? { |el| block.call(el).truthy? } ? RubyBool::TRUE : RubyBool::FALSE
  end

  def count : RubyInteger
    length
  end

  def count(&block : RubyObject -> RubyObject) : RubyInteger
    n = @data.count { |el| block.call(el).truthy? }
    RubyInteger.new(n.to_i64)
  end

  def sum : RubyObject
    return RubyInteger.new(0_i64) if @data.empty?
    acc = @data[0]
    @data[1..].each { |el| acc = acc + el }
    acc
  end

  def sum(init : RubyObject) : RubyObject
    acc = init
    @data.each { |el| acc = acc + el }
    acc
  end

  def flat_map(&block : RubyObject -> RubyObject) : RubyArray
    result = RubyArray.new
    @data.each do |el|
      val = block.call(el)
      case val
      when RubyArray then val.data.each { |inner| result.push(inner) }
      else result.push(val)
      end
    end
    result
  end

  def reduce(init : RubyObject, &block : RubyObject, RubyObject -> RubyObject) : RubyObject
    @data.reduce(init) { |acc, el| block.call(acc, el) }
  end

  def inject(init : RubyObject, &block : RubyObject, RubyObject -> RubyObject) : RubyObject
    reduce(init) { |acc, el| block.call(acc, el) }
  end

  def each_with_object(obj : RubyObject, &block : RubyObject, RubyObject ->) : RubyObject
    @data.each { |el| block.call(el, obj) }
    obj
  end

  def take(n : RubyObject) : RubyArray
    cnt = n.is_a?(RubyInteger) ? n.to_i64.to_i32 : 0
    RubyArray.new(@data.first(cnt))
  end

  def drop(n : RubyObject) : RubyArray
    cnt = n.is_a?(RubyInteger) ? n.to_i64.to_i32 : 0
    RubyArray.new(cnt < @data.size ? @data[cnt..] : [] of RubyObject)
  end

  def tally : RubyHash
    result = RubyHash.new
    @data.each do |el|
      cur = result[el]
      result[el] = cur.ruby_nil? ? RubyInteger.new(1_i64) : (cur + RubyInteger.new(1_i64))
    end
    result
  end

  def join(sep : RubyString) : RubyString
    RubyString.new(@data.map(&.to_s).join(sep.to_s))
  end

  def join(sep : RubyObject = RubyNil::INSTANCE) : RubyString
    sep_str = sep.ruby_nil? ? "" : sep.to_s
    RubyString.new(@data.map(&.to_s).join(sep_str))
  end

  def flatten(depth : RubyObject) : RubyArray
    result = RubyArray.new
    flatten_into(result)
    result
  end

  def each_slice(n : RubyObject) : RubyArray
    cnt = n.is_a?(RubyInteger) ? n.to_i64.to_i32 : 1
    cnt = 1 if cnt < 1
    result = RubyArray.new
    i = 0
    while i < @data.size
      slice = RubyArray.new(@data[i, [cnt, @data.size - i].min])
      result.push(slice)
      i += cnt
    end
    result
  end

  def each_cons(n : RubyObject) : RubyArray
    cnt = n.is_a?(RubyInteger) ? n.to_i64.to_i32 : 1
    cnt = 1 if cnt < 1
    result = RubyArray.new
    i = 0
    while i + cnt <= @data.size
      result.push(RubyArray.new(@data[i, cnt]))
      i += 1
    end
    result
  end

  def to_a : RubyArray
    self
  end

  def sample : RubyObject
    return RubyNil::INSTANCE if @data.empty?
    @data[Random.rand(@data.size)]
  end

  def shuffle : RubyArray
    RubyArray.new(@data.shuffle)
  end

  def rotate(n : RubyObject = RubyInteger.new(1_i64)) : RubyArray
    return self if @data.empty?
    cnt = n.is_a?(RubyInteger) ? n.to_i64.to_i32 % @data.size : 1
    RubyArray.new(@data[cnt..] + @data[...cnt])
  end

  private def ruby_cmp(a : RubyObject, b : RubyObject) : Int32
    return 0 unless a.is_a?(RubyInteger) && b.is_a?(RubyInteger)
    a <=> b
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
    # Support comparison with RubyTupleN and other array-like objects
    return false unless other.responds_to?(:length) && other.responds_to?(:[])
    other_len = other.length
    return false unless other_len.is_a?(RubyInteger) && other_len.to_i64 == @data.size.to_i64
    @data.each_with_index do |elem, i|
      return false unless elem == other[i.to_i64]
    end
    true
  end

  def hash : UInt64
    h = 0xdeadbeef_u64
    @data.each { |el| h = h &* 31 &+ el.hash }
    h
  end
end

# Multiple-assignment coercion: wrap a non-Array RHS in a single-element array.
def masgn_coerce(rhs : RubyObject) : RubyArray
  case rhs
  when RubyArray then rhs
  else RubyArray.new([rhs] of RubyObject)
  end
end
