class Time
  include Comparable

  def self.now  = Intrinsics.time_now
  def -(other)  = Intrinsics.time_minus(self, other)
  def +(other)  = Intrinsics.time_plus(self, other)
  def to_f      = Intrinsics.time_to_f(self)
  def to_i      = Intrinsics.time_to_i(self)
  def to_s      = Intrinsics.time_to_s(self)

  def <=>(other)
    return nil unless other.is_a?(Time)
    to_f <=> other.to_f
  end
end
