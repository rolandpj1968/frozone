class Float
  INFINITY   = Intrinsics.float_infinity
  NAN        = Intrinsics.float_nan
  MAX        = 1.7976931348623157e+308
  MIN        = 2.2250738585072014e-308
  EPSILON    = 2.220446049250313e-16
  DIG        = 15
  MANT_DIG   = 53
  MAX_EXP    = 1024
  MIN_EXP    = -1021
  MAX_10_EXP = 308
  MIN_10_EXP = -307
  RADIX      = 2

  def ==(v) = Intrinsics.float_eq(self, v)
  def eql?(v) = Intrinsics.float_eql(self, v)
  def hash = Intrinsics.float_hash(self)
  def <=>(v) = Intrinsics.float_spaceship(self, v)
  def to_s = Intrinsics.float_to_s(self)
  def inspect = Intrinsics.float_to_s(self)
  def to_i = Intrinsics.float_to_i(self)
  def to_int = Intrinsics.float_to_i(self)
  def to_f = Intrinsics.float_to_f(self)
  def to_r = Intrinsics.float_to_r(self)
  def abs = Intrinsics.float_abs(self)
  def magnitude = Intrinsics.float_abs(self)
  def ceil(n = nil) = Intrinsics.float_ceil(self, n)
  def floor(n = nil) = Intrinsics.float_floor(self, n)
  def round(n = nil) = Intrinsics.float_round(self, n)
  def truncate(n = nil) = Intrinsics.float_truncate(self, n)
  def nan? = Intrinsics.float_nan?(self)
  def infinite? = Intrinsics.float_infinite?(self)
  def finite? = Intrinsics.float_finite?(self)
  def zero? = Intrinsics.float_zero?(self)
  def positive? = Intrinsics.float_positive?(self)
  def negative? = Intrinsics.float_negative?(self)
  def divmod(v) = Intrinsics.float_divmod(self, v)
  def modulo(v) = Intrinsics.float__mod_(self, v.to_f)
  alias % modulo
  def <(v) = Intrinsics.float__lt_(self, v)
  def <=(v) = Intrinsics.float__le_(self, v)
  def >=(v) = Intrinsics.float__ge_(self, v)
  def >(v) = Intrinsics.float__gt_(self, v)
  def +(v) = Intrinsics.float__plus_(self, v)
  def -(v) = Intrinsics.float__minus_(self, v)
  def *(v) = Intrinsics.float__mul_(self, v)
  def /(v) = Intrinsics.float__div_(self, v)
  def %(v) = Intrinsics.float__mod_(self, v)
  def **(v) = Intrinsics.float__pow_(self, v)
  def -@ = 0.0 - self
  def +@ = self
  def coerce(v) = [v.to_f, self]
  def nonzero? = zero? ? nil : self
  def fdiv(v) = self / v.to_f
  def quo(v)  = self / v.to_f
  def div(v) = (self / v).floor
  def remainder(n) = self - n * (self / n).truncate
  def rationalize(eps = nil) = Intrinsics.float_rationalize(self, eps)
  def integer? = false
  def between?(min, max) = min <= self && self <= max
  def clamp(min_or_range, max = nil)
    if max.nil?
      lo = min_or_range.begin; hi = min_or_range.end
      return lo if lo && self < lo
      return hi if hi && (min_or_range.exclude_end? ? self >= hi : self > hi)
      self
    else
      return min_or_range if self < min_or_range
      return max if self > max
      self
    end
  end
  def numerator   = to_r.numerator
  def denominator = to_r.denominator

  def arg
    return self if nan?
    return Math::PI if (1.0 / self) == -Float::INFINITY  # -0.0
    self < 0 ? Math::PI : 0.0
  end

  alias angle arg
  alias phase arg
  def next_float = Intrinsics.float_next_float(self)
  def prev_float = Intrinsics.float_prev_float(self)
  def eql?(v) = v.is_a?(Float) && Intrinsics.float_eql(self, v)
  def <=>(v)
    return Intrinsics.float_spaceship(self, v) if v.is_a?(Float) || v.is_a?(Integer)
    begin; a, b = v.coerce(self); a <=> b; rescue; nil; end
  end
end
