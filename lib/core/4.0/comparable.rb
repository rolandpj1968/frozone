module Comparable
  def <(other)  = (self <=> other) < 0
  def <=(other) = (self <=> other) <= 0
  def >(other)  = (self <=> other) > 0
  def >=(other) = (self <=> other) >= 0
  def between?(min, max) = min <= self && self <= max
end
