class NilClass
  def nil? = true
  def to_s = ""
  def inspect = "nil"
  def to_a = []
  def to_i = 0
  def to_f = 0.0
  def to_h = {}
  def &(_) = false
  def |(other) = other ? true : false
  def =~(_) = nil
end
