class TrueClass
  TRUE_STR = "true".freeze

  def to_s = TRUE_STR
  def inspect = TRUE_STR

  def &(other) = other ? true : false
  def |(other) = true
  def ^(other) = other ? false : true

  def self.allocate
    raise TypeError, "allocate is not allowed for TrueClass"
  end

  def self.new(*)
    raise NoMethodError, "undefined method 'new' for TrueClass:Class"
  end
end
