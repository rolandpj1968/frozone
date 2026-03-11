class Float
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
  def modulo(v) = self - v * (self / v).floor
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
  def coerce(v) = [self.class.new(v.to_f), self]
  def nonzero? = zero? ? nil : self
  def fdiv(v) = self / v.to_f
  def div(v) = (self / v).floor
  def rationalize(eps = nil) = to_r
  def integer? = false
  def between?(min, max) = min <= self && self <= max
end
