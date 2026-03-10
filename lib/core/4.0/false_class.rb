class FalseClass
  def to_s = "false"
  def inspect = "false"
  def &(other) = false
  def |(other) = other ? true : false
  def ^(other) = other ? true : false
end
