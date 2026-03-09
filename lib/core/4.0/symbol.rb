class Symbol
  def hash = Intrinsics.symbol_hash(self)
  def eql?(v) = Intrinsics.symbol_eql(self, v)
end
