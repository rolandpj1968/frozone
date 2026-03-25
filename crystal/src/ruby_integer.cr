# RubyInteger — Crystal implementation of Ruby integer semantics.
#
# Ruby integers auto-promote from 64-bit fixnum to arbitrary-precision bignum
# on overflow.  This class stores either an Int64 or a BigInt and promotes
# transparently.
#
# Division and modulo follow Ruby's floor-division convention, which differs
# from Crystal/C truncation-toward-zero for negative operands:
#   Ruby:    -7 / 2  =>  -4   (floor toward -∞)
#   Crystal: -7 / 2  =>  -3   (truncation toward 0)
#   Ruby:    -7 % 3  =>   2   (sign of divisor)
#   Crystal: -7 % 3  =>  -1   (sign of dividend)

require "big"
require "./ruby_object"

class RubyInteger < RubyObject
  include Comparable(RubyInteger)

  # -------------------------------------------------------------------------
  # Storage — either a 64-bit fixnum or an arbitrary-precision bignum.
  # -------------------------------------------------------------------------

  @value : Int64 | BigInt

  # -------------------------------------------------------------------------
  # Constructors
  # -------------------------------------------------------------------------

  # Primary initializer accepting either Int64 or BigInt.
  def initialize(v : Int64 | BigInt)
    @value = v
  end

  def self.new(v : Int64) : RubyInteger
    allocate.tap { |o| o.initialize(v) }
  end

  def self.new(v : BigInt) : RubyInteger
    allocate.tap { |o| o.initialize(v) }
  end

  # Convenience: promote Int32 to Int64 immediately.
  def self.new(v : Int32) : RubyInteger
    allocate.tap { |o| o.initialize(v.to_i64) }
  end

  # Parse a decimal (or other base) string into a RubyInteger.
  # Raises ArgumentError on invalid input.
  def self.from_string(s : String, base : Int32 = 10) : RubyInteger
    stripped = s.strip
    raise ArgumentError.new("invalid integer string: #{s.inspect}") if stripped.empty?
    # Try Int64 first, fall back to BigInt
    begin
      new(stripped.to_i64(base: base))
    rescue ArgumentError
      # too large for Int64 or parse error
      begin
        new(BigInt.new(stripped, base))
      rescue ex
        raise ArgumentError.new("invalid integer string: #{s.inspect}")
      end
    end
  end

  # -------------------------------------------------------------------------
  # Internal helpers
  # -------------------------------------------------------------------------

  # True if the value fits in an Int64.
  def small? : Bool
    @value.is_a?(Int64)
  end

  # Expose the raw value (Int64 or BigInt).
  def raw : Int64 | BigInt
    @value
  end

  # -------------------------------------------------------------------------
  # Conversion
  # -------------------------------------------------------------------------

  def to_i64 : Int64
    case v = @value
    when Int64  then v
    when BigInt then v.to_i64  # raises OverflowError if too large
    else             raise "unreachable"
    end
  end

  def to_big : BigInt
    case v = @value
    when Int64  then v.to_big_i
    when BigInt then v
    else             raise "unreachable"
    end
  end

  def to_f64 : Float64
    case v = @value
    when Int64  then v.to_f64
    when BigInt then v.to_f64
    else             raise "unreachable"
    end
  end

  def to_f : RubyFloat
    RubyFloat.new(to_f64)
  end

  def to_s(base : Int32 = 10) : String
    case v = @value
    when Int64  then v.to_s(base)
    when BigInt then v.to_s(base)
    else             raise "unreachable"
    end
  end

  def inspect : String
    to_s
  end

  # -------------------------------------------------------------------------
  # Arithmetic helpers — produce a normalised RubyInteger (Int64 when possible)
  # -------------------------------------------------------------------------

  # Promote a BigInt result back to Int64 if it fits.
  protected def self.normalise(v : BigInt) : RubyInteger
    begin
      new(v.to_i64)
    rescue OverflowError
      new(v)
    end
  end

  private def normalise(v : BigInt) : RubyInteger
    RubyInteger.normalise(v)
  end

  # -------------------------------------------------------------------------
  # Arithmetic
  # -------------------------------------------------------------------------

  def +(other : RubyInteger) : RubyInteger
    case {a: @value, b: other.raw}
    when {a: Int64, b: Int64}
      a = @value.as(Int64)
      b = other.raw.as(Int64)
      begin
        RubyInteger.new(a &+ b == a + b ? a + b : raise OverflowError.new)
      rescue OverflowError
        normalise(a.to_big_i + b.to_big_i)
      end
    else
      normalise(to_big + other.to_big)
    end
  end

  def -(other : RubyInteger) : RubyInteger
    case {a: @value, b: other.raw}
    when {a: Int64, b: Int64}
      a = @value.as(Int64)
      b = other.raw.as(Int64)
      begin
        result = a.to_big_i - b.to_big_i
        normalise(result)
      end
    else
      normalise(to_big - other.to_big)
    end
  end

  def *(other : RubyInteger) : RubyInteger
    case {a: @value, b: other.raw}
    when {a: Int64, b: Int64}
      a = @value.as(Int64)
      b = other.raw.as(Int64)
      begin
        result = a.to_big_i * b.to_big_i
        normalise(result)
      end
    else
      normalise(to_big * other.to_big)
    end
  end

  # Integer division truncating toward negative infinity (floor division).
  # Ruby semantics: -7 / 2 => -4, not -3.
  def /(other : RubyInteger) : RubyInteger
    b = other.to_big
    raise DivisionByZeroError.new if b.zero?
    a = to_big
    q = a.tdiv(b)  # truncation-toward-zero (Crystal default)
    # Adjust to floor: if there's a remainder and signs differ, subtract 1
    r = a - q * b
    q -= 1 if !r.zero? && ((r < 0) != (b < 0))
    normalise(q)
  end

  # Modulo with Ruby sign-of-divisor semantics.
  # Ruby semantics: -7 % 3 => 2, not -1.
  def %(other : RubyInteger) : RubyInteger
    b = other.to_big
    raise DivisionByZeroError.new if b.zero?
    a = to_big
    r = a.remainder(b)  # remainder has sign of dividend (C/Crystal behaviour)
    # Adjust: if remainder is nonzero and signs differ between r and b, add b
    r += b if !r.zero? && ((r < 0) != (b < 0))
    normalise(r)
  end

  # Exponentiation.  Negative exponent yields 0 for integers (Ruby returns
  # a Rational in some contexts, but in pure integer context the result is 0).
  def **(other : RubyInteger) : RubyInteger
    exp_big = other.to_big
    if exp_big < 0
      return RubyInteger.new(0_i64)
    end
    begin
      exp_i = exp_big.to_i64
      if exp_i == 0
        return RubyInteger.new(1_i64)
      end
    rescue OverflowError
      # exponent is astronomically large — BigInt ** BigInt will handle it
    end
    normalise(to_big ** exp_big)
  end

  def - : RubyInteger
    case v = @value
    when Int64
      begin
        RubyInteger.new((-v.to_big_i).to_i64)
      rescue OverflowError
        normalise(-v.to_big_i)
      end
    when BigInt
      normalise(-v)
    else
      raise "unreachable"
    end
  end

  def abs : RubyInteger
    case v = @value
    when Int64
      if v >= 0_i64
        RubyInteger.new(v)
      else
        begin
          RubyInteger.new((-v.to_big_i).to_i64)
        rescue OverflowError
          normalise(v.to_big_i.abs)
        end
      end
    when BigInt
      normalise(v.abs)
    else
      raise "unreachable"
    end
  end

  # -------------------------------------------------------------------------
  # Bitwise
  # -------------------------------------------------------------------------

  def &(other : RubyInteger) : RubyInteger
    normalise(to_big & other.to_big)
  end

  def |(other : RubyInteger) : RubyInteger
    normalise(to_big | other.to_big)
  end

  def ^(other : RubyInteger) : RubyInteger
    normalise(to_big ^ other.to_big)
  end

  def ~ : RubyInteger
    # ~n == -(n+1) for two's-complement
    case v = @value
    when Int64
      RubyInteger.new(~v)
    when BigInt
      normalise(-(v + 1))
    else
      raise "unreachable"
    end
  end

  def <<(n : RubyInteger) : RubyInteger
    shift = n.to_i64
    if shift < 0
      return self >> RubyInteger.new(-shift)
    end
    normalise(to_big << shift.to_i32)
  end

  def >>(n : RubyInteger) : RubyInteger
    shift = n.to_i64
    if shift < 0
      return self << RubyInteger.new(-shift)
    end
    normalise(to_big >> shift.to_i32)
  end

  # -------------------------------------------------------------------------
  # Comparison
  # -------------------------------------------------------------------------

  def <=>(other : RubyInteger) : Int32
    to_big <=> other.to_big
  end

  def ==(other : RubyInteger) : Bool
    to_big == other.to_big
  end

  def ==(other : RubyObject) : Bool
    false
  end

  def <(other : RubyInteger) : Bool
    to_big < other.to_big
  end

  def <=(other : RubyInteger) : Bool
    to_big <= other.to_big
  end

  def >(other : RubyInteger) : Bool
    to_big > other.to_big
  end

  def >=(other : RubyInteger) : Bool
    to_big >= other.to_big
  end

  # -------------------------------------------------------------------------
  # Predicates
  # -------------------------------------------------------------------------

  def zero? : Bool
    case v = @value
    when Int64  then v == 0_i64
    when BigInt then v.zero?
    else             raise "unreachable"
    end
  end

  def positive? : Bool
    case v = @value
    when Int64  then v > 0_i64
    when BigInt then v > 0
    else             raise "unreachable"
    end
  end

  def negative? : Bool
    case v = @value
    when Int64  then v < 0_i64
    when BigInt then v < 0
    else             raise "unreachable"
    end
  end

  def odd? : Bool
    case v = @value
    when Int64  then v.odd?
    when BigInt then (v & 1) != 0
    else             raise "unreachable"
    end
  end

  def even? : Bool
    !odd?
  end

  # -------------------------------------------------------------------------
  # Number theory
  # -------------------------------------------------------------------------

  # Returns {quotient, remainder} using floor division (Ruby semantics).
  def divmod(other : RubyInteger) : {RubyInteger, RubyInteger}
    q = self / other
    r = self % other
    {q, r}
  end

  # Greatest common divisor using the Euclidean algorithm.
  # Works on BigInt for full precision and BigInt compatibility.
  def gcd(other : RubyInteger) : RubyInteger
    a = to_big.abs
    b = other.to_big.abs
    while b != 0
      t = b
      b = a.remainder(b)
      if b < 0
        b += t
      end
      b = a % b if b < 0
      a = t
    end
    # Simple Euclidean — redo cleanly
    a2 = to_big.abs
    b2 = other.to_big.abs
    until b2.zero?
      a2, b2 = b2, a2.remainder(b2).abs
    end
    normalise(a2)
  end

  def lcm(other : RubyInteger) : RubyInteger
    return RubyInteger.new(0_i64) if zero? || other.zero?
    g = gcd(other)
    (self.abs * other.abs) / g
  end

  # Decompose abs(self) into digits in the given base, least-significant first.
  # 0.digits => [0]
  def digits(base : RubyInteger) : Array(RubyInteger)
    b = base.to_big
    raise ArgumentError.new("base must be >= 2") if b < 2
    n = to_big.abs
    result = Array(RubyInteger).new
    if n.zero?
      result << RubyInteger.new(0_i64)
      return result
    end
    while n > 0
      result << normalise(n.remainder(b).abs)
      n = n.tdiv(b)
    end
    result
  end

  # Modular exponentiation when mod is given; otherwise equivalent to **.
  # Uses fast square-and-multiply for modular case.
  def pow(exp : RubyInteger, mod : RubyInteger? = nil) : RubyInteger
    if mod.nil?
      return self ** exp
    end
    m = mod.to_big
    raise ArgumentError.new("modulus must be positive") if m <= 0
    e = exp.to_big
    raise ArgumentError.new("negative exponent not supported for modular pow") if e < 0
    base = to_big.remainder(m)
    base += m if base < 0
    result = BigInt.new(1)
    while e > 0
      if (e & 1) == 1
        result = (result * base).remainder(m)
      end
      e = e >> 1
      base = (base * base).remainder(m)
    end
    normalise(result)
  end

  # Number of bits needed to represent the absolute value.
  # bit_length of 0 is 0.
  def bit_length : Int32
    n = to_big.abs
    return 0 if n.zero?
    count = 0
    tmp = n
    while tmp > 0
      count += 1
      tmp = tmp >> 1
    end
    count
  end

  # -------------------------------------------------------------------------
  # RubyObject overrides
  # -------------------------------------------------------------------------

  def hash : UInt64
    case v = @value
    when Int64  then v.hash
    when BigInt then v.hash
    else             raise "unreachable"
    end
  end
end
