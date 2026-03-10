class TrueClass
  def to_s = "true"
  def inspect = "true"
  def &(other) = other ? true : false
  def |(other) = true
  def ^(other) = other ? false : true
end
