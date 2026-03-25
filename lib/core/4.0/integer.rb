class Integer
  ROUND_NDIGITS_MAX = 1_073_741_824  # 2**30: MRI raises RangeError for round(ndigits) above this magnitude
  def succ = self + 1
  alias next succ
  def pred = self - 1
  def -@ = 0 - self
  def +@ = self
  def abs = self < 0 ? -self : self
  def zero? = self == 0
  def positive? = self > 0
  def negative? = self < 0
  def to_i = self
  alias to_int to_i
  def to_f = Intrinsics.integer_to_f(self)
  def to_s(base = nil) = Intrinsics.integer_to_s(self, base)
  def inspect = to_s
  def hash = Intrinsics.integer_hash(self)
  def eql?(v) = v.is_a?(Integer) && self == v
  def equal?(v) = self == v
  def ord = self
  def even? = self % 2 == 0
  def odd? = self % 2 != 0
  def ceil(n = 0)  = n >= 0 ? self : (self.to_f.ceil(n).to_i rescue self)
  def floor(n = 0) = n >= 0 ? self : (self.to_f.floor(n).to_i rescue self)
  def fdiv(n) = Intrinsics.integer_fdiv(self, n)
  def ~  = Intrinsics.integer_bitnot(self)
  def size = [(bit_length + 7) / 8, 8].max
  def bit_length = Intrinsics.integer_bit_length(self)
  def to_r = Intrinsics.integer_to_r(self)
  def to_c = Intrinsics.integer_to_c(self)
  def integer? = true
  def nonzero? = self == 0 ? nil : self
  def numerator = self
  def denominator = 1
  def rationalize(eps = nil) = Rational(self, 1)
  def between?(min, max) = self >= min && self <= max

  def <(v)   = v.is_a?(Integer) ? Intrinsics.integer__lt_(self, v) : __coerce_and_compare__(v, :<)
  def <=(v)  = v.is_a?(Integer) ? Intrinsics.integer__le_(self, v) : __coerce_and_compare__(v, :<=)
  def >=(v)  = v.is_a?(Integer) ? Intrinsics.integer__ge_(self, v) : __coerce_and_compare__(v, :>=)
  def >(v)   = v.is_a?(Integer) ? Intrinsics.integer__gt_(self, v) : __coerce_and_compare__(v, :>)
  def ==(v)  = v.is_a?(Integer) ? Intrinsics.integer__eq_(self, v) : (v == self rescue false)
  def ===(v) = v.is_a?(Integer) ? Intrinsics.integer__eq_(self, v) : (v == self rescue false)

  def +(v) = v.is_a?(Integer) ? Intrinsics.integer__plus_(self, v)  : __coerce_op__(v, :+)
  def -(v) = v.is_a?(Integer) ? Intrinsics.integer__minus_(self, v) : __coerce_op__(v, :-)
  def *(v) = v.is_a?(Integer) ? Intrinsics.integer__mul_(self, v)   : __coerce_op__(v, :*)
  def /(v) = v.is_a?(Integer) ? Intrinsics.integer__div_(self, v)   : __coerce_op__(v, :/)
  def %(v) = v.is_a?(Integer) ? Intrinsics.integer__mod_(self, v)   : __coerce_op__(v, :%)
  alias modulo %

  def **(v)
    if v.is_a?(Integer)
      raise ZeroDivisionError, "divided by 0" if self == 0 && v < 0
      return Intrinsics.integer__pow_(self, v)
    end
    if v.is_a?(Float)
      # Negative base with fractional exponent → Complex
      if self < 0 && v != v.floor
        r     = (-self).to_f ** v
        theta = Math::PI * v
        return Complex(r * Math.cos(theta), r * Math.sin(theta))
      end
      return to_f ** v
    end
    raise ZeroDivisionError, "divided by 0" if self == 0 && v.respond_to?(:negative?) && v.negative?
    __coerce_op__(v, :**)
  end

  def <=>(v)
    return Intrinsics.integer_spaceship(self, v) if v.is_a?(Integer)
    v.coerce(self).then { |a, b| a <=> b } rescue nil
  end

  def times(&block)
    return Enumerator.new(self) { |y| i = 0; while i < self; y.yield(i); i += 1; end } unless block
    i = 0; while i < self; block.call(i); i += 1; end; self
  end

  def upto(n, &block)
    return __step_enum__(n, 1) { |s| n >= s ? n - s + 1 : 0 } unless block
    i = self; while i <= n; block.call(i); i += 1; end; self
  end

  def downto(n, &block)
    return __step_enum__(n, -1) { |s| s >= n ? s - n + 1 : 0 } unless block
    i = self; while i >= n; block.call(i); i -= 1; end; self
  end

  def chr(enc = nil)
    resolved =
      if enc.nil? && self > 255
        di = Encoding.default_internal
        return Intrinsics.integer_chr(self, nil) if di.nil?
        di
      else
        enc
      end
    # CESU-8: BMP same as UTF-8; supplementary via surrogate pairs
    if resolved.is_a?(Encoding) && resolved.name == "CESU-8"
      raise RangeError, "#{self} out of char range" if self < 0 || self > 0x10FFFF
      if self < 0x10000
        return self.chr(Encoding::UTF_8)
      else
        u_prime = self - 0x10000
        hi = 0xD800 + (u_prime >> 10)
        lo = 0xDC00 + (u_prime & 0x3FF)
        bytes = [
          0xED, 0xA0 | ((hi >> 6) & 0x0F), 0x80 | (hi & 0x3F),
          0xED, 0xB0 | ((lo >> 6) & 0x0F), 0x80 | (lo & 0x3F)
        ]
        s = bytes.map { |b| b.chr(Encoding::ASCII_8BIT) }.join("")
        Intrinsics.string_force_encoding(s, resolved)
      end
    else
      Intrinsics.integer_chr(self, resolved)
    end
  end

  def round(n = 0, half: nil)
    unless n.is_a?(Integer)
      if n.nil?
        raise TypeError, "no implicit conversion of NilClass into Integer"
      elsif n.is_a?(Float)
        raise RangeError, "#{n} is out of range of integer" if n.infinite?
        raise TypeError, "no implicit conversion of Float into Integer"
      elsif n.respond_to?(:to_int)
        n = n.to_int
        raise TypeError, "can't convert to Integer" unless n.is_a?(Integer)
      else
        raise TypeError, "no implicit conversion of #{n.class} into Integer"
      end
    end
    raise RangeError, "integer #{n} too big to convert to `int'" if n > ROUND_NDIGITS_MAX || n < -ROUND_NDIGITS_MAX
    raise ArgumentError, "invalid rounding mode: #{half}" unless [nil, :up, :down, :even].include?(half)
    return self if n >= 0
    factor = 10 ** (-n)
    q, r = divmod(factor)
    base = q * factor
    two_r = 2 * r
    if two_r < factor
      base
    elsif two_r > factor
      base + factor
    else
      case half
      when :down  then self >= 0 ? base : base + factor
      when :even  then q.even? ? base : base + factor
      else             self >= 0 ? base + factor : base
      end
    end
  end

  def truncate(n = 0)
    return self if n >= 0
    factor = 10 ** (-n)
    q, r = divmod(factor)
    q += 1 if self < 0 && r != 0
    q * factor
  end

  def divmod(n)
    if n.is_a?(Integer)
      [self / n, self % n]
    elsif n.is_a?(Float)
      raise ZeroDivisionError, "divided by 0" if n == 0.0
      raise FloatDomainError, "NaN" if n.nan?
      q = (self.to_f / n).floor
      [q, self.to_f % n]
    else
      begin
        a, b = n.send(:coerce, self)
      rescue NoMethodError
        raise TypeError, "#{n.class} can't be coerced into Integer"
      end
      a.divmod(b)
    end
  end

  def div(n)
    if n.is_a?(Integer)
      raise ZeroDivisionError, "divided by 0" if n == 0
      self / n
    elsif n.is_a?(Float)
      raise ZeroDivisionError, "divided by 0" if n == 0.0
      (self.to_f / n).floor.to_i
    elsif n.respond_to?(:coerce)
      a, b = n.send(:coerce, self)
      a.div(b)
    else
      raise TypeError, "#{n.class} can't be coerced into Integer"
    end
  end

  def remainder(n)
    raise TypeError, "#{n.class} can't be coerced into Integer" unless n.is_a?(Integer) || n.is_a?(Float) || n.respond_to?(:coerce)
    raise ZeroDivisionError, "divided by 0" if n == 0
    if n.is_a?(Integer)
      q, r = divmod(n)
      r != 0 && (self < 0) != (n < 0) ? r - n : r
    elsif n.is_a?(Float)
      self.to_f.remainder(n)
    else
      a, b = n.coerce(self)
      a.remainder(b)
    end
  end

  def gcd(n)
    raise TypeError, "not an integer" unless n.is_a?(Integer)
    a, b = self.abs, n.abs
    while b != 0; a, b = b, a % b; end
    a
  end

  def lcm(n)
    raise TypeError, "not an integer" unless n.is_a?(Integer)
    (self == 0 || n == 0) ? 0 : (self.abs / self.gcd(n) * n.abs)
  end

  def gcdlcm(n)
    raise TypeError, "not an integer" unless n.is_a?(Integer)
    [gcd(n), lcm(n)]
  end

  def digits(base = 10)
    base = base.to_int if base.respond_to?(:to_int) && !base.is_a?(Integer)
    raise ArgumentError, "invalid radix #{base}" if base < 2
    raise Math::DomainError, "out of domain" if self < 0
    return [0] if self == 0
    n = self; result = []
    while n > 0; result << n % base; n /= base; end
    result
  end

  def pow(n, m = :__undefined__)
    if m.equal?(:__undefined__)
      self ** n
    else
      raise TypeError, "2nd argument not allowed unless all arguments are integers" unless n.is_a?(Integer) && m.is_a?(Integer)
      raise RangeError, "2nd argument not allowed unless all arguments are integers" if n < 0
      raise ZeroDivisionError, "divided by 0" if m == 0
      Intrinsics.integer__pow_(self, n) % m
    end
  end

  def &(n)
    return Intrinsics.integer_bitand(self, n) if n.is_a?(Integer)
    raise TypeError, "no implicit conversion of Float into Integer" if n.is_a?(Float)
    begin; a, b = n.coerce(self); return a & b; rescue NoMethodError; end
    raise TypeError, "no implicit conversion of #{n.class} into Integer"
  end

  def |(n)
    return Intrinsics.integer_bitor(self, n) if n.is_a?(Integer)
    raise TypeError, "no implicit conversion of Float into Integer" if n.is_a?(Float)
    begin; a, b = n.coerce(self); return a | b; rescue NoMethodError; end
    raise TypeError, "no implicit conversion of #{n.class} into Integer"
  end

  def ^(n)
    return Intrinsics.integer_bitxor(self, n) if n.is_a?(Integer)
    raise TypeError, "no implicit conversion of Float into Integer" if n.is_a?(Float)
    begin; a, b = n.coerce(self); return a ^ b; rescue NoMethodError; end
    raise TypeError, "no implicit conversion of #{n.class} into Integer"
  end

  def <<(n)
    n = __coerce_to_int__(n)
    Intrinsics.integer_lshift(self, n)
  end

  def >>(n)
    n = __coerce_to_int__(n)
    Intrinsics.integer_rshift(self, n)
  end

  def [](idx, len = nil)
    if idx.is_a?(Range)
      lo = idx.begin
      hi = idx.end
      excl = idx.exclude_end?
      # Convert Float boundaries (raise FloatDomainError)
      if lo.is_a?(Float)
        raise FloatDomainError, lo.infinite? == 1 ? "Infinity" : lo.infinite? == -1 ? "-Infinity" : lo.inspect
      end
      if hi.is_a?(Float)
        raise FloatDomainError, hi.infinite? == 1 ? "Infinity" : hi.infinite? == -1 ? "-Infinity" : hi.inspect
      end
      if lo.nil?
        # (..i) form: returns 0 if all bits 0..hi_pos are 0, else ArgumentError
        hi_pos = hi.is_a?(Integer) ? hi : hi.to_int
        hi_pos -= 1 if excl
        mask = (1 << (hi_pos + 1)) - 1
        return 0 if (self & mask) == 0
        raise ArgumentError, "The beginless range for Integer#[] results in infinity"
      end
      lo_i = lo.is_a?(Integer) ? lo : lo.to_int
      if hi.nil?
        return self >> lo_i
      end
      hi_i = hi.is_a?(Integer) ? hi : hi.to_int
      hi_pos = excl ? hi_i - 1 : hi_i
      return self >> lo_i if hi_pos < lo_i
      width = hi_pos - lo_i + 1
      (self >> lo_i) & ((1 << width) - 1)
    else
      unless idx.is_a?(Integer)
        if idx.is_a?(Float)
          idx = idx.to_i
        elsif idx.respond_to?(:to_int)
          idx = idx.to_int
          raise TypeError, "to_int should return Integer" unless idx.is_a?(Integer)
        else
          raise TypeError, "no implicit conversion of #{idx.class} into Integer"
        end
      end
      if len.nil?
        Intrinsics.integer_bit(self, idx)
      else
        len = len.to_int unless len.is_a?(Integer)
        return self >> idx if len < 0
        (self >> idx) & ((1 << len) - 1)
      end
    end
  end

  def allbits?(mask)
    mask = __coerce_to_int__(mask)
    (self & mask) == mask
  end

  def anybits?(mask)
    mask = __coerce_to_int__(mask)
    (self & mask) != 0
  end

  def nobits?(mask)
    mask = __coerce_to_int__(mask)
    (self & mask) == 0
  end

  def ceildiv(n)
    q, r = divmod(n)
    r == 0 ? q : q + 1
  end

  def coerce(other)
    if other.is_a?(Integer)
      [other, self]
    elsif other.is_a?(Float)
      [other, self.to_f]
    elsif other.is_a?(String)
      [Float(other), self.to_f]
    elsif other.nil?
      raise TypeError, "can't coerce NilClass into Integer"
    elsif other.respond_to?(:to_f)
      result = other.to_f
      raise TypeError, "can't coerce #{other.class} into Float (#{other.class}#to_f should return Float)" unless result.is_a?(Float)
      [result, self.to_f]
    else
      raise TypeError, "can't coerce #{other.class} into Integer"
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

  def self.try_convert(val)
    return val if val.is_a?(Integer)
    return nil unless val.respond_to?(:to_int)
    result = val.to_int
    return nil if result.nil?
    raise TypeError, "can't convert #{val.class} into Integer (#{val.class}#to_int gives #{result.class})" unless result.is_a?(Integer)
    result
  end

  def self.sqrt(n)
    n = n.to_int if n.respond_to?(:to_int) && !n.is_a?(Integer)
    raise TypeError, "no implicit conversion of #{n.class} into Integer" unless n.is_a?(Integer)
    raise Math::DomainError, "out of domain" if n < 0
    return 0 if n == 0
    sqrt_f = Math.sqrt(n.to_f)
    x = sqrt_f.infinite? ? 2 ** ((n.bit_length + 1) / 2) : sqrt_f.floor.to_i
    # Newton's method for large integers (converges quadratically)
    loop do
      x1 = (x + n / x) / 2
      break if x1 >= x
      x = x1
    end
    x -= 1 if x * x > n
    x
  end
  private

  # Call coerce even if private; propagate non-NoMethodError exceptions
  def __coerce_op__(v, op)
    begin
      a, b = v.send(:coerce, self)
    rescue NoMethodError
      raise TypeError, "#{v.class} can't be coerced into Integer"
    end
    a.send(op, b)
  end

  def __step_enum__(n, step, &sz)
    s = self
    sz_proc = -> { sz.call(s) rescue raise ArgumentError, "comparison of #{n.class} with #{s.class} failed" }
    Enumerator.new(sz_proc) { |y| i = s; while step > 0 ? i <= n : i >= n; y.yield(i); i += step; end }
  end

  def __coerce_and_compare__(other, op)
    a, b = other.coerce(self)
    a.send(op, b)
  rescue TypeError, NoMethodError
    raise ArgumentError, "comparison of #{self.class} with #{other.class} failed"
  end

end
