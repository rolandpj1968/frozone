# Lightweight 2-element container for compiled fixed-size arrays.
# Single allocation with 2 inline pointer fields — ~3x less overhead
# than RubyArray (which allocates wrapper + Crystal Array + buffer).
class RubyPair < RubyObject
  @left : RubyObject
  @right : RubyObject

  def initialize(@left, @right)
  end

  def [](i : Int64) : RubyObject
    i == 0 ? @left : @right
  end

  def [](i : RubyObject) : RubyObject
    self[i.to_i64]
  end

  def [](i : Int32) : RubyObject
    self[i.to_i64]
  end

  def length : RubyInteger
    RubyInteger.new(2_i64)
  end

  def size : RubyInteger
    length
  end

  def to_s : String
    "[#{@left.to_s}, #{@right.to_s}]"
  end

  def inspect : String
    "[#{@left.inspect}, #{@right.inspect}]"
  end

  def ruby_nil? : Bool
    false
  end

  def truthy? : Bool
    true
  end
end
