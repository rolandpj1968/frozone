class Integer
  # TODO - promotions
  # For now assume v is also an Integer

  def < (v) = Intrinsics.integer__lt_(self, v)
  def <=(v) = Intrinsics.integer__le_(self, v)
  def >=(v) = Intrinsics.integer__ge_(self, v)
  def > (v) = Intrinsics.integer__gt_(self, v)
  def ==(v) = Intrinsics.integer__eq_(self, v) # TODO - should be alias for ===

  def + (v) = Intrinsics.integer__plus_(self, v)
  def - (v) = Intrinsics.integer__minus_(self, v)

  def hash = Intrinsics.integer_hash(self)
end
