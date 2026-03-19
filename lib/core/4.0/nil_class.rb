class NilClass
  NIL_STR = "".freeze

  def nil? = true
  def to_s = NIL_STR
  def inspect = "nil"
  def to_a = []
  def to_i = 0
  def to_f = 0.0
  def to_h = {}
  def to_r = Rational(0, 1)
  def to_c = Complex(0, 0)
  def rationalize(eps = nil) = Rational(0, 1)
  def &(_) = false
  def |(other) = other ? true : false
  def ^(other) = other ? true : false
  def =~(_) = nil
  def <=>(other) = nil

  def self.allocate
    raise TypeError, "allocate is not allowed for NilClass"
  end

  def self.new(*)
    raise NoMethodError, "undefined method 'new' for NilClass:Class"
  end
end
