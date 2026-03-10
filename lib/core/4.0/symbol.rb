class Symbol
  def to_s = Intrinsics.symbol_to_s(self)
  def to_sym = self
  def inspect = Intrinsics.symbol_inspect(self)

  def hash = Intrinsics.symbol_hash(self)
  def eql?(v) = Intrinsics.symbol_eql(self, v)
end
