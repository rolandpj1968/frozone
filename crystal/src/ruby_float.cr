# RubyFloat — Crystal implementation of Ruby float semantics.
#
# Ruby floats are IEEE 754 double-precision (Float64) with Ruby-specific
# semantics for division, modulo, rounding, and string formatting.
#
# Key differences from Crystal Float64:
#   - Integer division (`idiv`) returns RubyInteger (floor toward -∞)
#   - Modulo (`%`) has sign-of-divisor semantics: -7.0 % 3 => 2.0
#   - `to_s` always includes a decimal point: 1.0.to_s => "1.0"
#   - `<=>` returns nil (Int32?) for NaN comparisons
#
# NOTE: We do NOT include Comparable(RubyFloat) because Comparable requires
# `<=>` to return `Int32`, but Ruby float `<=>` returns nil for NaN.
# All comparison operators are defined explicitly below.

require "./ruby_integer"

class RubyFloat < RubyObject
  # -------------------------------------------------------------------------
  # Constants
  # -------------------------------------------------------------------------

  INFINITY = RubyFloat.new(Float64::INFINITY)
  NAN      = RubyFloat.new(Float64::NAN)
  EPSILON  = RubyFloat.new(Float64::EPSILON)
  MAX      = RubyFloat.new(Float64::MAX)
  MIN      = RubyFloat.new(Float64::MIN_POSITIVE)
  DIG      = 15
  MANT_DIG = 53

  # -------------------------------------------------------------------------
  # Storage
  # -------------------------------------------------------------------------

  @value : Float64

  # -------------------------------------------------------------------------
  # Constructor
  # -------------------------------------------------------------------------

  def initialize(v : Float64)
    @value = v
  end

  # Convenience: promote Int64 to Float64.
  def self.new(v : Int64) : RubyFloat
    new(v.to_f64)
  end

  # -------------------------------------------------------------------------
  # Raw access
  # -------------------------------------------------------------------------

  def raw : Float64
    @value
  end

  # -------------------------------------------------------------------------
  # Arithmetic — Float op Float
  # -------------------------------------------------------------------------

  def +(other : RubyFloat) : RubyFloat
    RubyFloat.new(@value + other.raw)
  end

  def -(other : RubyFloat) : RubyFloat
    RubyFloat.new(@value - other.raw)
  end

  def *(other : RubyFloat) : RubyFloat
    RubyFloat.new(@value * other.raw)
  end

  def /(other : RubyFloat) : RubyFloat
    RubyFloat.new(@value / other.raw)
  end

  # Modulo with Ruby sign-of-divisor semantics.
  # -7.0 % 3 => 2.0; 7.0 % -3 => -2.0
  def %(other : RubyFloat) : RubyFloat
    b = other.raw
    return RubyFloat.new(Float64::NAN) if b == 0.0 || @value.nan? || b.nan?
    r = @value.remainder(b)  # sign of dividend (Crystal/C semantics)
    # Adjust: if nonzero and signs differ between r and b, add b
    r += b if r != 0.0 && ((r < 0.0) != (b < 0.0))
    RubyFloat.new(r)
  end

  def **(other : RubyFloat) : RubyFloat
    RubyFloat.new(@value ** other.raw)
  end

  # -------------------------------------------------------------------------
  # Arithmetic — Float op Integer (promote integer to float)
  # -------------------------------------------------------------------------

  def +(other : RubyInteger) : RubyFloat
    self + RubyFloat.new(other.to_f64)
  end

  def -(other : RubyInteger) : RubyFloat
    self - RubyFloat.new(other.to_f64)
  end

  def *(other : RubyInteger) : RubyFloat
    self * RubyFloat.new(other.to_f64)
  end

  def /(other : RubyInteger) : RubyFloat
    self / RubyFloat.new(other.to_f64)
  end

  def %(other : RubyInteger) : RubyFloat
    self % RubyFloat.new(other.to_f64)
  end

  def **(other : RubyInteger) : RubyFloat
    self ** RubyFloat.new(other.to_f64)
  end

  # -------------------------------------------------------------------------
  # Unary operators
  # -------------------------------------------------------------------------

  def - : RubyFloat
    RubyFloat.new(-@value)
  end

  def abs : RubyFloat
    RubyFloat.new(@value.abs)
  end

  # -------------------------------------------------------------------------
  # Integer division — returns RubyInteger (floor toward -∞)
  # -------------------------------------------------------------------------

  def idiv(other : RubyFloat) : RubyInteger
    b = other.raw
    raise DivisionByZeroError.new if b == 0.0
    result = (@value / b).floor
    RubyInteger.new(result.to_i64)
  end

  def idiv(other : RubyInteger) : RubyInteger
    idiv(RubyFloat.new(other.to_f64))
  end

  # -------------------------------------------------------------------------
  # divmod — {floor_quotient_as_integer, remainder_as_float}
  # -------------------------------------------------------------------------

  def divmod(other : RubyFloat) : {RubyInteger, RubyFloat}
    q = idiv(other)
    r = self % other
    {q, r}
  end

  def divmod(other : RubyInteger) : {RubyInteger, RubyFloat}
    divmod(RubyFloat.new(other.to_f64))
  end

  # -------------------------------------------------------------------------
  # Comparison — nil for NaN (Ruby <=> returns nil for incomparable)
  # -------------------------------------------------------------------------

  # Returns nil if either operand is NaN, otherwise -1/0/1.
  def <=>(other : RubyFloat) : Int32?
    return nil if @value.nan? || other.raw.nan?
    @value <=> other.raw
  end

  def ==(other : RubyFloat) : Bool
    return false if @value.nan? || other.raw.nan?
    @value == other.raw
  end

  def ==(other : RubyInteger) : Bool
    return false if @value.nan?
    @value == other.to_f64
  end

  def ==(other : RubyObject) : Bool
    false
  end

  def <(other : RubyFloat) : Bool
    return false if @value.nan? || other.raw.nan?
    @value < other.raw
  end

  def <=(other : RubyFloat) : Bool
    return false if @value.nan? || other.raw.nan?
    @value <= other.raw
  end

  def >(other : RubyFloat) : Bool
    return false if @value.nan? || other.raw.nan?
    @value > other.raw
  end

  def >=(other : RubyFloat) : Bool
    return false if @value.nan? || other.raw.nan?
    @value >= other.raw
  end

  def <(other : RubyInteger) : Bool
    return false if @value.nan?
    @value < other.to_f64
  end

  def <=(other : RubyInteger) : Bool
    return false if @value.nan?
    @value <= other.to_f64
  end

  def >(other : RubyInteger) : Bool
    return false if @value.nan?
    @value > other.to_f64
  end

  def >=(other : RubyInteger) : Bool
    return false if @value.nan?
    @value >= other.to_f64
  end

  # -------------------------------------------------------------------------
  # Rounding — ndigits=0 returns RubyInteger; ndigits!=0 returns RubyFloat
  # -------------------------------------------------------------------------

  def floor(ndigits : Int32 = 0) : RubyInteger | RubyFloat
    if ndigits == 0
      RubyInteger.new(@value.floor.to_i64)
    else
      factor = 10.0 ** ndigits
      RubyFloat.new((@value * factor).floor / factor)
    end
  end

  def ceil(ndigits : Int32 = 0) : RubyInteger | RubyFloat
    if ndigits == 0
      RubyInteger.new(@value.ceil.to_i64)
    else
      factor = 10.0 ** ndigits
      RubyFloat.new((@value * factor).ceil / factor)
    end
  end

  def round(ndigits : Int32 = 0) : RubyInteger | RubyFloat
    if ndigits == 0
      RubyInteger.new(@value.round.to_i64)
    else
      factor = 10.0 ** ndigits
      RubyFloat.new((@value * factor).round / factor)
    end
  end

  def truncate(ndigits : Int32 = 0) : RubyInteger | RubyFloat
    if ndigits == 0
      RubyInteger.new(@value.to_i64)
    else
      factor = 10.0 ** ndigits
      RubyFloat.new((@value * factor).to_i64.to_f64 / factor)
    end
  end

  # -------------------------------------------------------------------------
  # Conversion
  # -------------------------------------------------------------------------

  # Truncate toward zero, like Ruby's Float#to_i / Float#to_int.
  def to_i : RubyInteger
    RubyInteger.new(@value.to_i64)
  end

  def to_f64 : Float64
    @value
  end

  def to_f : Float64
    @value
  end

  # Ruby float formatting: always includes decimal point.
  # Examples: 1.0 => "1.0", 1.5 => "1.5", 1.25 => "1.25"
  # Special: Float::INFINITY => "Infinity", -Float::INFINITY => "-Infinity",
  #          Float::NAN => "NaN"
  def to_s : String
    if @value.nan?
      return "NaN"
    end
    if @value.infinite?
      return @value > 0.0 ? "Infinity" : "-Infinity"
    end
    # Use Crystal's default float formatting and ensure there is a decimal point
    s = @value.to_s
    # Crystal may produce "1.0" or "1.5e10" etc.
    # Ensure there is always a '.' for finite non-scientific notation.
    if s.includes?('.') || s.includes?('e') || s.includes?('E')
      s
    else
      s + ".0"
    end
  end

  def inspect : String
    to_s
  end

  # -------------------------------------------------------------------------
  # Predicates
  # -------------------------------------------------------------------------

  def nan? : Bool
    @value.nan?
  end

  # Returns -1 if negative infinity, 1 if positive infinity, 0 if finite.
  def infinite? : Int32
    if @value == Float64::INFINITY
      1
    elsif @value == -Float64::INFINITY
      -1
    else
      0
    end
  end

  def finite? : Bool
    @value.finite?
  end

  def zero? : Bool
    @value == 0.0
  end

  def positive? : Bool
    !@value.nan? && @value > 0.0
  end

  def negative? : Bool
    !@value.nan? && @value < 0.0
  end

  # -------------------------------------------------------------------------
  # Hash
  # -------------------------------------------------------------------------

  def hash : UInt64
    @value.hash
  end
end
