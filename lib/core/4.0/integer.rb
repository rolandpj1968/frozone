class Integer
  # TODO - promotions
  # For now assume v is also an Integer

  def < (v) = Intrinsics.int__lt_(self, v)
  def <=(v) = Intrinsics.int__le_(self, v)
  def >=(v) = Intrinsics.int__ge_(self, v)
  def > (v) = Intrinsics.int__gt_(self, v)
  def ==(v) = Intrinsics.int__eq_(self, v) # TODO - should be alias for ===

  def + (v) = Intrinsics.int__plus_(self, v)
  def - (v) = Intrinsics.int__minus_(self, v)
end
