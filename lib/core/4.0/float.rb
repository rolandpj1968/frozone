class Float
  INFINITY = Intrinsics.float_infinity
  NAN = Intrinsics.float_nan
  MAX = 1.7976931348623157e+308
  MIN = 2.2250738585072014e-308
  EPSILON = 2.220446049250313e-16
  DIG = 15
  MANT_DIG = 53
  MAX_EXP = 1024
  MIN_EXP = -1021
  MAX_10_EXP = 308
  MIN_10_EXP = -307
  RADIX = 2

  class << self
    def new(*) = raise(NoMethodError, "undefined method 'new' for class Float")
    def allocate = raise(TypeError, "allocator undefined for Float")
  end

  def eql?(v) = v.is_a?(Float) && self == v
  def hash = Intrinsics.float_hash(self)
  def to_s = Intrinsics.float_to_s(self)
  def inspect = Intrinsics.float_to_s(self)
  def to_i = truncate
  def to_int = to_i
  def to_f = self
  def to_r = Intrinsics.float_to_r(self)
  def abs = zero? ? 0.0 : self < 0.0 ? -self : self
  def magnitude = abs
  def nan? = self != self
  def infinite? = self == INFINITY ? 1 : self == -INFINITY ? -1 : nil
  def finite? = !nan? && self != Float::INFINITY && self != -Float::INFINITY
  def zero? = self == 0.0
  def positive? = self > 0.0
  def negative? = self < 0.0
  def integer? = false
  def nonzero? = zero? ? nil : self
  def -@ = 0.0 - self
  def +@ = self
  def ===(other) = self == other
  def divmod(v) = Intrinsics.float_divmod(self, v)
  def div(v) = (self / v).floor
  def remainder(n) = Intrinsics.float_remainder(self, n)
  def rationalize(eps = nil) = Intrinsics.float_rationalize(self, eps)
  def between?(min, max) = min <= self && self <= max
  def next_float = Intrinsics.float_next_float(self)
  def prev_float = Intrinsics.float_prev_float(self)
  # Arithmetic with coerce support; missing coerce (NoMethodError) raises TypeError
  def +(other) = other.is_a?(Float) ? Intrinsics.float__plus_(self, other) : __coerce_op__(other, :+)
  def -(other) = other.is_a?(Float) ? Intrinsics.float__minus_(self, other) : __coerce_op__(other, :-)
  def *(other) = other.is_a?(Float) ? Intrinsics.float__mul_(self, other) : __coerce_op__(other, :*)
  def /(other) = other.is_a?(Float) ? Intrinsics.float__div_(self, other) : __coerce_op__(other, :/)
  def %(other) = other.is_a?(Float) ? Intrinsics.float__mod_(self, other) : __coerce_op__(other, :%)
  alias modulo %
  # Comparison with coerce; no coerce or TypeError from coerce raises ArgumentError
  def <(other) = other.is_a?(Float) ? Intrinsics.float__lt_(self, other) : __coerce_and_compare__(other, :<)
  def <=(other) = other.is_a?(Float) ? Intrinsics.float__le_(self, other) : __coerce_and_compare__(other, :<=)
  def >=(other) = other.is_a?(Float) ? Intrinsics.float__ge_(self, other) : __coerce_and_compare__(other, :>=)
  def >(other) = other.is_a?(Float) ? Intrinsics.float__gt_(self, other) : __coerce_and_compare__(other, :>)
  # == calls other == self if coercion fails (TypeError/NoMethodError rescue)
  def ==(other) = other.is_a?(Float) ? Intrinsics.float_eq(self, other) : (other.coerce(self).then { |a, b| a == b } rescue other == self)
  def ceil(n = nil) = Intrinsics.float_ceil(self, n.nil? ? nil : __coerce_to_int__(n))
  def floor(n = nil) = Intrinsics.float_floor(self, n.nil? ? nil : __coerce_to_int__(n))
  def truncate(n = nil) = Intrinsics.float_truncate(self, n.nil? ? nil : __coerce_to_int__(n))

  def **(other)
    if other.is_a?(Float)
      # Negative base with fractional exponent -> Complex
      if self < 0 && other != other.floor
        r = abs ** other
        theta = Math::PI * other
        return Complex(r * Math.cos(theta), r * Math.sin(theta))
      end
      return Intrinsics.float__pow_(self, other)
    end
    __coerce_op__(other, :**)
  end

  def <=>(other)
    return Intrinsics.float_spaceship(self, other) if other.is_a?(Float)
    si = infinite?
    if si && other.respond_to?(:infinite?)
      other_inf = other.infinite?
      other_inf_i = other_inf.nil? ? 0 : other_inf.to_i
      return 0 if si == other_inf_i && other_inf_i != 0
      return si > other_inf_i ? 1 : -1
    end
    return nil unless other.respond_to?(:coerce)
    begin
      coerced = other.coerce(self)
    rescue TypeError, NoMethodError
      return nil
    end
    raise TypeError, "coerce must return [x, y]" unless coerced.is_a?(Array) && coerced.length == 2
    coerced[0] <=> coerced[1]
  end

  def coerce(v)
    return [v.to_f, self] if v.respond_to?(:to_f)
    raise TypeError, "can't coerce #{v.class} into Float"
  end

  def fdiv(other)
    if other.is_a?(Float) || other.is_a?(Integer)
      self / other.to_f
    elsif other.is_a?(Complex)
      denom = other.real.to_f ** 2 + other.imaginary.to_f ** 2
      Complex(self * other.real.to_f / denom, -self * other.imaginary.to_f / denom)
    elsif other.respond_to?(:coerce)
      a, b = other.coerce(self)
      a.fdiv(b)
    else
      raise TypeError, "#{other.class} can't be coerced into Float"
    end
  end

  def quo(other)
    if other.is_a?(Float) || other.is_a?(Integer)
      self / other.to_f
    elsif other.respond_to?(:coerce)
      a, b = other.coerce(self)
      a.quo(b)
    else
      raise TypeError, "#{other.class} can't be coerced into Float"
    end
  end

  def round(n = :__undefined__, half: nil)
    if n.equal?(:__undefined__)
      Intrinsics.float_round(self, nil, half)
    else
      raise TypeError, "no implicit conversion of #{n.class} into Integer" if n.nil?
      n = __coerce_to_int__(n)
      Intrinsics.float_round(self, n, half)
    end
  end

  def numerator
    return self if nan?
    return self if !finite?
    to_r.numerator
  end

  def denominator
    return 1 if nan? || !finite?
    to_r.denominator
  end

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

  def arg
    return self if nan?
    return Math::PI if (1.0 / self) == -Float::INFINITY  # -0.0
    self < 0 ? Math::PI : 0.0
  end
  alias angle arg
  alias phase arg

  private

  def __coerce_op__(other, op)
    a, b = other.coerce(self)
    a.send(op, b)
  rescue NoMethodError
    raise TypeError, "#{other.class} can't be coerced into Float"
  end

  def __coerce_and_compare__(other, op)
    a, b = other.coerce(self)
    a.send(op, b)
  rescue TypeError, NoMethodError
    raise ArgumentError, "comparison of #{self.class} with #{other.class} failed"
  end

end
