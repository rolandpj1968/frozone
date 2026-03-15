module Comparable
  def <(other)
    r = self <=> other
    raise ArgumentError, "comparison of #{self.class} with #{other.class} failed" if r.nil?
    r < 0
  end

  def <=(other)
    r = self <=> other
    raise ArgumentError, "comparison of #{self.class} with #{other.class} failed" if r.nil?
    r <= 0
  end

  def >(other)
    r = self <=> other
    raise ArgumentError, "comparison of #{self.class} with #{other.class} failed" if r.nil?
    r > 0
  end

  def >=(other)
    r = self <=> other
    raise ArgumentError, "comparison of #{self.class} with #{other.class} failed" if r.nil?
    r >= 0
  end

  def ==(other)
    r = self <=> other
    return false if r.nil?
    r == 0
  end

  def between?(min, max) = min <= self && self <= max

  def clamp(min_or_range, max = nil)
    if max.nil?
      lo = min_or_range.begin; hi = min_or_range.end
      return lo if lo && self < lo
      return hi if hi && (min_or_range.exclude_end? ? self >= hi : self > hi)
      self
    else
      raise ArgumentError, "min argument must be smaller than max argument" if min_or_range > max
      return min_or_range if self < min_or_range
      return max if self > max
      self
    end
  end
end
