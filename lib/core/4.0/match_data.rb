class MatchData
  def to_a = Intrinsics.match_data_to_a(self)
  def size = Intrinsics.match_data_size(self)
  def length = size
  def captures = Intrinsics.match_data_captures(self)
  def pre_match = Intrinsics.match_data_pre_match(self)
  def post_match = Intrinsics.match_data_post_match(self)
  def begin(n) = Intrinsics.match_data_begin(self, n)
  def end(n) = Intrinsics.match_data_end(self, n)
  def offset(n) = [self.begin(n), self.end(n)]
  def bytebegin(n) = Intrinsics.match_data_bytebegin(self, n)
  def byteend(n) = Intrinsics.match_data_byteend(self, n)
  def byteoffset(n) = [bytebegin(n), byteend(n)]
  def match_length(n) = Intrinsics.match_data_match_length(self, n)
  def names = Intrinsics.match_data_names(self)
  def to_s = self[0].to_s
  def hash = Intrinsics.match_data_hash(self)
  def string = (@string ||= Intrinsics.match_data_string(self))
  def regexp = (@regexp ||= Intrinsics.match_data_regexp(self))
  def deconstruct = captures

  def self.allocate
    raise NoMethodError, "undefined method 'allocate' for class 'MatchData'"
  end

  def [](index, length = nil)
    if length
      Intrinsics.match_data_slice(self, index, length)
    elsif index.is_a?(Range)
      Intrinsics.match_data_slice_range(self, index)
    else
      Intrinsics.match_data_index(self, index)
    end
  end

  def named_captures(symbolize_names: false)
    h = Intrinsics.match_data_named_captures(self)
    symbolize_names ? h.transform_keys(&:to_sym) : h
  end

  def values_at(*indices)
    n = size
    indices.flat_map do |i|
      if i.is_a?(Range)
        Intrinsics.match_data_values_at_range(self, i, n)
      elsif i.is_a?(Integer) || i.is_a?(Symbol) || i.is_a?(String)
        [self[i]]
      elsif i.respond_to?(:to_int)
        [self[i.to_int]]
      else
        raise TypeError, "no implicit conversion of #{i.class} into Integer"
      end
    end
  end

  def deconstruct_keys(keys)
    raise TypeError, "wrong argument type #{keys.class} (expected Array)" unless keys.nil? || keys.is_a?(Array)
    h = named_captures.transform_keys(&:to_sym)
    return h if keys.nil?
    return {} if keys.length > h.length
    result = {}
    keys.each do |k|
      raise TypeError, "wrong argument type #{k.class} (expected Symbol)" unless k.is_a?(Symbol)
      break unless h.key?(k)
      result[k] = h[k]
    end
    result
  end

  def match(n)
    v = self[n]
    v.nil? ? nil : v
  end

  def inspect
    ms = self[0].inspect
    nc = regexp.named_captures
    if nc.empty?
      caps = captures
      if caps.empty?
        "#<MatchData #{ms}>"
      else
        pairs = caps.each_with_index.map { |c, i| " #{i + 1}:#{c.inspect}" }.join
        "#<MatchData #{ms}#{pairs}>"
      end
    else
      pairs = nc.keys.map { |name| " #{name}:#{self[name].inspect}" }.join
      "#<MatchData #{ms}#{pairs}>"
    end
  end

  def ==(other)
    return false unless other.is_a?(MatchData)
    string == other.string && regexp == other.regexp && to_a == other.to_a
  end

  alias eql? ==
end
