class FalseClass
  FALSE_STR = "false".freeze

  def to_s = FALSE_STR
  def inspect = FALSE_STR
  def &(other) = false
  def |(other) = other ? true : false
  def ^(other) = other ? true : false

  def self.allocate = raise(TypeError, "allocate is not allowed for FalseClass")
  def self.new(*) = raise(NoMethodError, "undefined method 'new' for FalseClass:Class")
end
