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

  def eql?(v) = v.is_a?(Float) && Intrinsics.float_eql(self, v)
  def hash = Intrinsics.float_hash(self)
  def to_s = Intrinsics.float_to_s(self)
  def inspect = Intrinsics.float_to_s(self)
  def to_i = Intrinsics.float_to_i(self)
  def to_int = Intrinsics.float_to_i(self)
  def to_f = self
  def to_r = Intrinsics.float_to_r(self)
  def abs = Intrinsics.float_abs(self)
  def magnitude = Intrinsics.float_abs(self)
  def nan? = Intrinsics.float_nan?(self)
  def infinite? = Intrinsics.float_infinite?(self)
  def finite? = Intrinsics.float_finite?(self)
  def zero? = Intrinsics.float_zero?(self)
  def positive? = Intrinsics.float_positive?(self)
  def negative? = Intrinsics.float_negative?(self)
  def integer? = false
  def nonzero? = zero? ? nil : self
  def -@ = 0.0 - self
  def +@ = self
  def self.new(*) = raise(NoMethodError, "undefined method 'new' for class Float")
  def self.allocate = raise(TypeError, "allocator undefined for Float")
  # Arithmetic with coerce support; missing coerce (NoMethodError) raises TypeError
  def +(other)
    return Intrinsics.float__plus_(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    begin; a, b = other.coerce(self); rescue NoMethodError; raise TypeError, "#{other.class} can't be coerced into Float"; end
    a + b
  end

  def -(other)
    return Intrinsics.float__minus_(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    begin; a, b = other.coerce(self); rescue NoMethodError; raise TypeError, "#{other.class} can't be coerced into Float"; end
    a - b
  end

  def *(other)
    return Intrinsics.float__mul_(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    begin; a, b = other.coerce(self); rescue NoMethodError; raise TypeError, "#{other.class} can't be coerced into Float"; end
    a * b
  end

  def /(other)
    return Intrinsics.float__div_(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    begin; a, b = other.coerce(self); rescue NoMethodError; raise TypeError, "#{other.class} can't be coerced into Float"; end
    a / b
  end

  def %(other)
    return Intrinsics.float__mod_(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    begin; a, b = other.coerce(self); rescue NoMethodError; raise TypeError, "#{other.class} can't be coerced into Float"; end
    a % b
  end
  alias modulo %

  def **(other)
    if other.is_a?(Float) || other.is_a?(Integer)
      # Negative base with fractional exponent returns Complex
      if self < 0 && other.is_a?(Float) && other != other.floor
        r = Intrinsics.float_abs(self) ** other
        theta = Math::PI * other
        return Complex(r * Math.cos(theta), r * Math.sin(theta))
      end
      return Intrinsics.float__pow_(self, other)
    end
    begin; a, b = other.coerce(self); rescue NoMethodError; raise TypeError, "#{other.class} can't be coerced into Float"; end
    a ** b
  end
  # Comparison with coerce; no coerce or TypeError from coerce raises ArgumentError
  def <(other)
    return Intrinsics.float__lt_(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    __coerce_and_compare__(other, :<)
  end

  def <=(other)
    return Intrinsics.float__le_(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    __coerce_and_compare__(other, :<=)
  end

  def >=(other)
    return Intrinsics.float__ge_(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    __coerce_and_compare__(other, :>=)
  end

  def >(other)
    return Intrinsics.float__gt_(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    __coerce_and_compare__(other, :>)
  end
  # == calls other == self if coercion fails (TypeError/NoMethodError rescue)
  def ===(other) = self == other

  def ==(other)
    return Intrinsics.float_eq(self, other) if other.is_a?(Float) || other.is_a?(Integer)
    begin
      a, b = other.coerce(self)
      a == b
    rescue TypeError, NoMethodError
      other == self
    end
  end
  # <=> with infinite? protocol and TypeError for bad coerce return
  def divmod(v) = Intrinsics.float_divmod(self, v)
  def div(v) = (self / v).floor
  def remainder(n) = Intrinsics.float_remainder(self, n)
  def rationalize(eps = nil) = Intrinsics.float_rationalize(self, eps)
  def between?(min, max) = min <= self && self <= max
  def next_float = Intrinsics.float_next_float(self)
  def prev_float = Intrinsics.float_prev_float(self)

  def <=>(other)
    return Intrinsics.float_spaceship(self, other) if other.is_a?(Float) || other.is_a?(Integer)
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

  def ceil(n = nil)
    if n.nil?
      Intrinsics.float_ceil(self, nil)
    else
      n = __coerce_to_int__(n)
      Intrinsics.float_ceil(self, n)
    end
  end

  def floor(n = nil)
    if n.nil?
      Intrinsics.float_floor(self, nil)
    else
      n = __coerce_to_int__(n)
      Intrinsics.float_floor(self, n)
    end
  end

  def truncate(n = nil)
    if n.nil?
      Intrinsics.float_truncate(self, nil)
    else
      n = __coerce_to_int__(n)
      Intrinsics.float_truncate(self, n)
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

  def __coerce_and_compare__(other, op)
    a, b = other.coerce(self)
    a.send(op, b)
  rescue TypeError, NoMethodError
    raise ArgumentError, "comparison of #{self.class} with #{other.class} failed"
  end

end
