class Integer
  # TODO - promotions
  # For now assume v is also an Integer

  def < (v) = Intrinsics.integer__lt_(self, v)
  def <=(v) = Intrinsics.integer__le_(self, v)
  def >=(v) = Intrinsics.integer__ge_(self, v)
  def > (v) = Intrinsics.integer__gt_(self, v)
  def ==(v); return false unless v.is_a?(Integer); Intrinsics.integer__eq_(self, v); end

  def +(v) = Intrinsics.integer__plus_(self, v)
  def -(v) = Intrinsics.integer__minus_(self, v)
  def *(v) = Intrinsics.integer__mul_(self, v)
  def /(v) = Intrinsics.integer__div_(self, v)
  def %(v) = Intrinsics.integer__mod_(self, v)
  def **(v) = Intrinsics.integer__pow_(self, v)

  def succ = self + 1
  alias next succ
  def pred = self - 1

  def -@ = 0 - self

  def abs = Intrinsics.integer_abs(self)
  def zero? = self == 0
  def positive? = self > 0
  def negative? = self < 0
  def to_i = self
  def to_s = Intrinsics.integer_to_s(self)
  def inspect = to_s

  def <=>(v) = Intrinsics.integer_spaceship(self, v)

  def hash = Intrinsics.integer_hash(self)
  def eql?(v) = Intrinsics.integer_eql(self, v)

  def times;   i = 0;    while i < self; yield i; i += 1; end; self; end
  def upto(n); i = self; while i <= n;   yield i; i += 1; end; self; end
  def downto(n); i = self; while i >= n; yield i; i -= 1; end; self; end

  def chr(enc = nil) = Intrinsics.integer_chr(self, enc)
  def ord = self
  def even? = self % 2 == 0
  def odd?  = self % 2 != 0
  def ceil(n = 0)  = n >= 0 ? self : (self.to_f.ceil(n).to_i rescue self)
  def floor(n = 0) = n >= 0 ? self : (self.to_f.floor(n).to_i rescue self)
  def round(n = 0) = n >= 0 ? self : (self.to_f.round(n).to_i rescue self)
  def truncate(n = 0) = self
  def divmod(n) = [self / n, self % n]
  def gcd(n)
    a, b = self.abs, n.abs
    while b != 0; a, b = b, a % b; end
    a
  end

  def lcm(n) = (self == 0 || n == 0) ? 0 : (self.abs / self.gcd(n) * n.abs)

  def digits(base = 10)
    return [0] if self == 0
    n = self.abs; result = []
    while n > 0; result << n % base; n /= base; end
    result
  end

  def pow(n, m = nil) = m ? Intrinsics.integer__pow_(self, n) % m : Intrinsics.integer__pow_(self, n)
  def &(n) = Intrinsics.integer_bitand(self, n)
  def |(n) = Intrinsics.integer_bitor(self, n)
  def ^(n) = Intrinsics.integer_bitxor(self, n)
  def ~    = Intrinsics.integer_bitnot(self)
  def <<(n) = Intrinsics.integer_lshift(self, n)
  def >>(n) = Intrinsics.integer_rshift(self, n)
  def [](n) = Intrinsics.integer_bit(self, n)
  def size  = 8
  def bit_length = Intrinsics.integer_bit_length(self)
  def to_r = Intrinsics.integer_to_r(self)
  def to_c = Intrinsics.integer_to_c(self)
  def integer? = true
  def nonzero? = self == 0 ? nil : self

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
end
