require "./ruby_object"
require "./ruby_integer"
require "./ruby_nil"
require "./ruby_bool"
require "./ruby_string"

class RubyRange < RubyObject
  getter begin_val : RubyObject
  getter end_val   : RubyObject
  getter exclusive : Bool

  def initialize(@begin_val : RubyObject, @end_val : RubyObject, @exclusive : Bool)
  end

  def to_s : String
    "#{@begin_val.to_s}#{@exclusive ? "..." : ".."}#{@end_val.to_s}"
  end

  def inspect : String
    to_s
  end

  def include?(val : RubyObject) : RubyBool
    b = @begin_val
    e = @end_val
    if b.is_a?(RubyInteger) && e.is_a?(RubyInteger) && val.is_a?(RubyInteger)
      bv = b.to_i64
      ev = e.to_i64
      vv = val.to_i64
      ok = vv >= bv && (@exclusive ? vv < ev : vv <= ev)
      ok ? RubyBool::TRUE : RubyBool::FALSE
    else
      RubyBool::FALSE
    end
  end

  def to_a : RubyArray
    result = [] of RubyObject
    each { |v| result << v }
    RubyArray.new(result)
  end

  def each(&block : RubyObject -> _) : RubyObject
    b = @begin_val
    e = @end_val
    if b.is_a?(RubyInteger) && e.is_a?(RubyInteger)
      bv = b.to_i64
      ev = e.to_i64
      limit = @exclusive ? ev : ev + 1
      i = bv
      while i < limit
        block.call(RubyInteger.new(i))
        i += 1
      end
    end
    RubyNil::INSTANCE
  end

  # Range#map → RubyArray of block results.
  # Used by hoisted-into-execute-phase constant initialisers like
  # `LUT = (0..N).map { |i| ... }` (see vm.rb's
  # hoist_expensive_class_constants! and the AOT splitter).
  def map(&block : RubyObject -> RubyObject) : RubyArray
    result = [] of RubyObject
    each { |v| result << block.call(v) }
    RubyArray.new(result)
  end

  def size : RubyObject
    b = @begin_val
    e = @end_val
    if b.is_a?(RubyInteger) && e.is_a?(RubyInteger)
      bv = b.to_i64
      ev = e.to_i64
      sz = @exclusive ? (ev - bv) : (ev - bv + 1)
      RubyInteger.new([sz, 0_i64].max)
    else
      RubyNil::INSTANCE
    end
  end

  def first : RubyObject
    @begin_val
  end

  def last : RubyObject
    @end_val
  end

  def ==(other : RubyRange) : Bool
    @begin_val == other.begin_val && @end_val == other.end_val && @exclusive == other.exclusive
  end

  def ==(other : RubyObject) : Bool
    false
  end

  def hash : UInt64
    @begin_val.hash &* 31 &+ @end_val.hash &* 37 &+ (@exclusive ? 1_u64 : 0_u64)
  end
end
