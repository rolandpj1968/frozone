class String
  def hash = Intrinsics.string_hash(self)
  def eql?(v) = Intrinsics.string_eql(self, v)
end
