class MatchData
  def to_a = Intrinsics.match_data_to_a(self)
  def [](index) = Intrinsics.match_data_index(self, index)
  def size = Intrinsics.match_data_size(self)
  def length = size
  def captures = Intrinsics.match_data_captures(self)
  def pre_match = Intrinsics.match_data_pre_match(self)
  def post_match = Intrinsics.match_data_post_match(self)
  def string = Intrinsics.match_data_string(self)
  def regexp = Intrinsics.match_data_regexp(self)
  def begin(n) = Intrinsics.match_data_begin(self, n)
  def end(n) = Intrinsics.match_data_end(self, n)
  def offset(n) = [self.begin(n), self.end(n)]
  def named_captures = Intrinsics.match_data_named_captures(self)
  def names = Intrinsics.match_data_names(self)
  def to_s = self[0].to_s
  def inspect = "#<MatchData #{self[0].inspect}>"

  def ==(other)
    return false unless other.is_a?(MatchData)
    string == other.string && regexp == other.regexp && to_a == other.to_a
  end

  alias eql? ==
end
