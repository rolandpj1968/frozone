class MatchData
  def to_a = Intrinsics.match_data_to_a(self)

  def [](index, length = nil)
    if length
      Intrinsics.match_data_slice(self, index, length)
    elsif index.is_a?(Range)
      Intrinsics.match_data_slice_range(self, index)
    else
      Intrinsics.match_data_index(self, index)
    end
  end

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

  def bytebegin(n) = Intrinsics.match_data_bytebegin(self, n)
  def byteend(n) = Intrinsics.match_data_byteend(self, n)
  def byteoffset(n) = [bytebegin(n), byteend(n)]
  def match_length(n) = Intrinsics.match_data_match_length(self, n)

  def named_captures = Intrinsics.match_data_named_captures(self)
  def names = Intrinsics.match_data_names(self)

  def values_at(*indices)
    indices.flat_map do |i|
      if i.is_a?(Range)
        Intrinsics.match_data_slice_range(self, i)
      else
        [self[i]]
      end
    end
  end

  def deconstruct
    captures
  end

  def deconstruct_keys(keys)
    raise TypeError, "wrong argument type #{keys.class} (expected Array or nil)" unless keys.nil? || keys.is_a?(Array)
    h = named_captures
    return h if keys.nil?
    result = {}
    keys.each do |k|
      sym_k = k.is_a?(Symbol) ? k : k.to_sym
      break unless h.key?(sym_k)
      result[sym_k] = h[sym_k]
    end
    result
  end

  def match(n)
    v = self[n]
    v.nil? ? nil : v
  end

  def to_s = self[0].to_s

  def inspect
    ms = self[0].inspect
    nc = regexp.named_captures
    if nc.empty?
      "#<MatchData #{ms}>"
    else
      pairs = nc.keys.map { |name| " #{name}=#{self[name].inspect}" }.join
      "#<MatchData #{ms}#{pairs}>"
    end
  end

  def hash = Intrinsics.match_data_hash(self)

  def ==(other)
    return false unless other.is_a?(MatchData)
    string == other.string && regexp == other.regexp && to_a == other.to_a
  end

  alias eql? ==
end
