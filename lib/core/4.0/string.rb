class String
  def +(v) = Intrinsics.string_plus(self, v)
  def length = Intrinsics.string_length(self)
  alias size length
  def to_s = Intrinsics.string_to_s(self)
  def to_i = Intrinsics.string_to_i(self)
  def inspect = Intrinsics.string_inspect(self)

  def <=>(v) = Intrinsics.string_spaceship(self, v)
  def ==(v) = Intrinsics.string_eql(self, v)

  def hash = Intrinsics.string_hash(self)
  def eql?(v) = Intrinsics.string_eql(self, v)
end
