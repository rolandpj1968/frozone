class Integer
  def _coerce_op(v, op)
    if v.respond_to?(:coerce)
      a, b = v.coerce(self)
      a.send(op, b)
    else
      raise TypeError, "#{v.class} can't be coerced into Integer"
    end
  end

  private :_coerce_op

  def < (v)
    return Intrinsics.integer__lt_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :<)
  end

  def <=(v)
    return Intrinsics.integer__le_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :<=)
  end

  def >=(v)
    return Intrinsics.integer__ge_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :>=)
  end

  def > (v)
    return Intrinsics.integer__gt_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :>)
  end

  def ==(v)
    return Intrinsics.integer__eq_(self, v) if v.is_a?(Integer)
    begin; v == self; rescue; false; end
  end

  alias === ==

  def +(v)
    return Intrinsics.integer__plus_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :+)
  end

  def -(v)
    return Intrinsics.integer__minus_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :-)
  end

  def *(v)
    return Intrinsics.integer__mul_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :*)
  end

  def /(v)
    return Intrinsics.integer__div_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :/)
  end

  def %(v)
    return Intrinsics.integer__mod_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :%)
  end

  def **(v)
    return Intrinsics.integer__pow_(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    _coerce_op(v, :**)
  end

  def succ = self + 1
  alias next succ
  def pred = self - 1

  def -@ = 0 - self
  def +@ = self

  def abs = Intrinsics.integer_abs(self)
  def zero? = self == 0
  def positive? = self > 0
  def negative? = self < 0
  def to_i = self
  alias to_int to_i
  def to_f = Intrinsics.integer_to_f(self)
  def to_s(base = nil) = Intrinsics.integer_to_s(self, base)
  def inspect = to_s

  def <=>(v)
    return Intrinsics.integer_spaceship(self, v) if v.is_a?(Integer) || v.is_a?(Float)
    begin
      a, b = v.coerce(self)
      a <=> b
    rescue
      nil
    end
  end

  def hash = Intrinsics.integer_hash(self)
  def eql?(v) = Intrinsics.integer_eql(self, v)

  def times
    unless block_given?
      n = self
      return Enumerator.new(n) { |y| i = 0; while i < n; y.yield(i); i += 1; end }
    end
    i = 0; while i < self; yield i; i += 1; end; self
  end

  def upto(n)
    unless block_given?
      sz = n >= self ? n - self + 1 : 0
      s = self
      return Enumerator.new(sz) { |y| i = s; while i <= n; y.yield(i); i += 1; end }
    end
    i = self; while i <= n; yield i; i += 1; end; self
  end

  def downto(n)
    unless block_given?
      sz = self >= n ? self - n + 1 : 0
      s = self
      return Enumerator.new(sz) { |y| i = s; while i >= n; y.yield(i); i -= 1; end }
    end
    i = self; while i >= n; yield i; i -= 1; end; self
  end

  def chr(enc = nil) = Intrinsics.integer_chr(self, enc)
  def ord = self
  def even? = self % 2 == 0
  def odd?  = self % 2 != 0
  def ceil(n = 0)  = n >= 0 ? self : (self.to_f.ceil(n).to_i rescue self)
  def floor(n = 0) = n >= 0 ? self : (self.to_f.floor(n).to_i rescue self)

  def round(n = 0, half: nil)
    if !n.is_a?(Integer)
      if n.nil?
        raise TypeError, "no implicit conversion of NilClass into Integer"
      elsif n.respond_to?(:to_int)
        n = n.to_int
        raise TypeError, "can't convert to Integer" unless n.is_a?(Integer)
      else
        raise TypeError, "no implicit conversion of #{n.class} into Integer"
      end
    end
    return self if n >= 0 && half.nil?
    return self.to_f.round(n).to_i rescue self if n < 0
    self
  end

  def truncate(n = 0) = self
  def divmod(n) = [self / n, self % n]

  def div(n)
    if n.is_a?(Integer)
      raise ZeroDivisionError, "divided by 0" if n == 0
      q = self / n
      q -= 1 if (self ^ n) < 0 && q * n != self
      q
    elsif n.is_a?(Float)
      raise ZeroDivisionError, "divided by 0" if n == 0.0
      (self.to_f / n).floor.to_i
    elsif n.respond_to?(:coerce)
      a, b = n.coerce(self)
      a.div(b)
    else
      raise TypeError, "#{n.class} can't be coerced into Integer"
    end
  end

  def fdiv(n)
    if n.respond_to?(:coerce)
      a, b = n.coerce(self)
      a.to_f / b.to_f
    else
      self.to_f / n.to_f
    end
  end

  def remainder(n)
    raise TypeError, "#{n.class} can't be coerced into Integer" unless n.is_a?(Numeric)
    self - n * (self.to_f / n.to_f).truncate
  end

  def gcd(n)
    a, b = self.abs, n.abs
    while b != 0; a, b = b, a % b; end
    a
  end

  def lcm(n) = (self == 0 || n == 0) ? 0 : (self.abs / self.gcd(n) * n.abs)

  def gcdlcm(n) = [gcd(n), lcm(n)]

  def digits(base = 10)
    base = base.to_int if base.respond_to?(:to_int) && !base.is_a?(Integer)
    raise ArgumentError, "invalid radix #{base}" if base < 2
    raise Math::DomainError, "out of domain" if self < 0
    return [0] if self == 0
    n = self; result = []
    while n > 0; result << n % base; n /= base; end
    result
  end

  def pow(n, m = nil) = m ? Intrinsics.integer__pow_(self, n) % m : Intrinsics.integer__pow_(self, n)

  def &(n)
    unless n.is_a?(Integer)
      n = n.to_int if n.respond_to?(:to_int)
      raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
    end
    Intrinsics.integer_bitand(self, n)
  end

  def |(n)
    unless n.is_a?(Integer)
      n = n.to_int if n.respond_to?(:to_int)
      raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
    end
    Intrinsics.integer_bitor(self, n)
  end

  def ^(n)
    unless n.is_a?(Integer)
      n = n.to_int if n.respond_to?(:to_int)
      raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
    end
    Intrinsics.integer_bitxor(self, n)
  end

  def ~    = Intrinsics.integer_bitnot(self)

  def <<(n)
    n = n.to_int if !n.is_a?(Integer) && n.respond_to?(:to_int)
    raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
    Intrinsics.integer_lshift(self, n)
  end

  def >>(n)
    n = n.to_int if !n.is_a?(Integer) && n.respond_to?(:to_int)
    raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
    Intrinsics.integer_rshift(self, n)
  end

  def [](n, len = nil)
    unless n.is_a?(Integer)
      if n.respond_to?(:to_int)
        n = n.to_int
        raise TypeError, "to_int should return Integer" unless n.is_a?(Integer)
      else
        raise TypeError, "no implicit conversion of #{n.class} into Integer"
      end
    end
    Intrinsics.integer_bit(self, n)
  end
  def size  = 8
  def bit_length = Intrinsics.integer_bit_length(self)
  def to_r = Intrinsics.integer_to_r(self)
  def to_c = Intrinsics.integer_to_c(self)
  def integer? = true
  def nonzero? = self == 0 ? nil : self

  def numerator   = self
  def denominator = 1
  def rationalize(eps = nil) = Rational(self, 1)

  def _coerce_to_int(mask)
    return mask if mask.is_a?(Integer)
    if mask.respond_to?(:to_int)
      r = mask.to_int
      raise TypeError, "to_int should return Integer" unless r.is_a?(Integer)
      r
    else
      raise TypeError, "Integer expected"
    end
  end

  private :_coerce_to_int

  def allbits?(mask)
    mask = _coerce_to_int(mask)
    (self & mask) == mask
  end

  def anybits?(mask)
    mask = _coerce_to_int(mask)
    (self & mask) != 0
  end

  def nobits?(mask)
    mask = _coerce_to_int(mask)
    (self & mask) == 0
  end

  def ceildiv(n) = -(-self / n)

  def coerce(other)
    if other.is_a?(Integer)
      [other, self]
    elsif other.is_a?(Float)
      [other, self.to_f]
    else
      raise TypeError, "#{other.class} can't be coerced into Integer"
    end
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

  def between?(min, max) = self >= min && self <= max

  def self.try_convert(val)
    return val if val.is_a?(Integer)
    return nil unless val.respond_to?(:to_int)
    result = val.to_int
    raise TypeError, "can't convert #{val.class} into Integer (#{val.class}#to_int gives #{result.class})" unless result.is_a?(Integer)
    result
  end

  def self.sqrt(n)
    n = n.to_int if n.respond_to?(:to_int) && !n.is_a?(Integer)
    raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
    raise Math::DomainError, "out of domain" if n < 0
    return 0 if n == 0
    # Newton's method for integer square root
    x = Math.sqrt(n.to_f).floor.to_i
    x -= 1 while x * x > n
    x += 1 while (x + 1) * (x + 1) <= n
    x
  end
end
