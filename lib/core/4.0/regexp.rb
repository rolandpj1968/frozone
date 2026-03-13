class Regexp
  def ==(v) = Intrinsics.regexp_eq(self, v)
  alias eql? ==
  def source = Intrinsics.regexp_source(self)
  def options = Intrinsics.regexp_options(self)
  def inspect = Intrinsics.regexp_inspect(self)
  def to_s = Intrinsics.regexp_to_s(self)
  def casefold? = Intrinsics.regexp_casefold(self)
  def fixed_encoding? = Intrinsics.regexp_fixed_encoding(self)
  def match(str) = Intrinsics.regexp_match(self, str)
  def =~(str) = Intrinsics.regexp_match_index(self, str)
end
