class Integer
  # TODO - promotions
  # For now assume v is also an Integer

  def < (v) = Intrinsics.integer__lt_(self, v)
  def <=(v) = Intrinsics.integer__le_(self, v)
  def >=(v) = Intrinsics.integer__ge_(self, v)
  def > (v) = Intrinsics.integer__gt_(self, v)
  def ==(v) = Intrinsics.integer__eq_(self, v) # TODO - should be alias for ===

  def +(v) = Intrinsics.integer__plus_(self, v)
  def -(v) = Intrinsics.integer__minus_(self, v)
  def *(v) = Intrinsics.integer__mul_(self, v)
  def /(v) = Intrinsics.integer__div_(self, v)
  def %(v) = Intrinsics.integer__mod_(self, v)
  def **(v) = Intrinsics.integer__pow_(self, v)

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
end
