class Symbol
  def to_s = Intrinsics.symbol_to_s(self)
  def to_sym = self
  def to_proc; s = self; proc { |o, *args| o.send(s, *args) }; end
  def inspect = Intrinsics.symbol_inspect(self)

  def hash = Intrinsics.symbol_hash(self)
  def eql?(v) = Intrinsics.symbol_eql(self, v)
  def ==(v) = v.is_a?(Symbol) && to_s == v.to_s
  def <=>(v) = v.is_a?(Symbol) ? to_s <=> v.to_s : nil

  def succ = to_s.succ.to_sym
  alias next succ

  def length = to_s.length
  alias size length

  def empty? = to_s.empty?
  def upcase = to_s.upcase.to_sym
  def downcase = to_s.downcase.to_sym
  def capitalize = to_s.capitalize.to_sym
  def encoding = to_s.encoding
  def match(pattern) = to_s.match(pattern)
  def match?(pattern) = to_s.match?(pattern)
  def [](idx, len = nil) = len ? to_s[idx, len] : to_s[idx]

  include Comparable
end
