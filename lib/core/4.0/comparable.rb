module Comparable
  def <(other) = __cmp__(other) <  0
  def <=(other) = __cmp__(other) <= 0
  def >(other) = __cmp__(other) >  0
  def >=(other) = __cmp__(other) >= 0
  def between?(min, max) = min <= self && self <= max

  def ==(other)
    return true if equal?(other)
    r = begin
      self <=> other
    rescue NoMethodError
      return false
    end
    return false if r.nil?
    raise ArgumentError, "comparison of #{self.class} with #{other} failed" unless r.is_a?(Numeric)
    r == 0
  end

  def clamp(min_or_range, max = :__undefined__)
    if max.equal?(:__undefined__)
      # Range form
      lo = min_or_range.begin; hi = min_or_range.end
      raise ArgumentError, "cannot clamp with an exclusive range" if min_or_range.exclude_end? && hi
      if lo
        c = self <=> lo
        raise ArgumentError, "comparison of #{self.class} with #{lo.class} failed" if c.nil?
        return lo if c < 0
      end
      if hi
        c = self <=> hi
        raise ArgumentError, "comparison of #{self.class} with #{hi.class} failed" if c.nil?
        return hi if c > 0
      end
      self
    else
      # Two-arg form: clamp(min, max)
      lo = min_or_range; hi = max
      if lo && hi
        c = lo <=> hi
        raise ArgumentError, "min argument must be smaller than max argument" if c.nil? || c > 0
      end
      if lo
        c = self <=> lo
        raise ArgumentError, "comparison of #{self.class} with #{lo.class} failed" if c.nil?
        return lo if c < 0
      end
      if hi
        c = self <=> hi
        raise ArgumentError, "comparison of #{self.class} with #{hi.class} failed" if c.nil?
        return hi if c > 0
      end
      self
    end
  end
  private

  def __cmp__(other)
    r = self <=> other
    raise ArgumentError, "comparison of #{self.class} with #{other} failed" if r.nil? || !r.is_a?(Numeric)
    r
  end
end
