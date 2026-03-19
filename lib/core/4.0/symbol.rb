class Symbol
  include Comparable

  def to_s = Intrinsics.symbol_to_s(self)
  alias id2name to_s
  def name = to_s.freeze
  def to_sym = self
  alias intern to_sym
  def inspect = Intrinsics.symbol_inspect(self)
  def hash = Intrinsics.symbol_hash(self)
  def eql?(v) = self == v
  def ==(v) = v.is_a?(Symbol) && to_s == v.to_s
  def <=>(v) = v.is_a?(Symbol) ? to_s <=> v.to_s : nil
  def succ = to_s.succ.to_sym
  alias next succ
  def length = to_s.length
  alias size length
  def empty? = to_s.empty?
  def upcase(*args) = to_s.upcase(*args).to_sym
  def downcase(*args) = to_s.downcase(*args).to_sym
  def capitalize(*args) = to_s.capitalize(*args).to_sym
  def swapcase(*args) = to_s.swapcase(*args).to_sym
  def encoding = to_s.encoding
  def start_with?(*prefixes) = to_s.start_with?(*prefixes)
  def end_with?(*suffixes) = to_s.end_with?(*suffixes)
  def =~(pattern) = to_s =~ pattern

  def self.allocate
    raise TypeError, "allocating an instance of Symbol"
  end

  def self.new(*)
    raise NoMethodError, "undefined method 'new' for Symbol:Class"
  end

  def self.all_symbols
    Intrinsics.symbol_all_symbols
  end

  def to_proc
    sym = self
    ->(obj, *args, **kwargs, &block) { obj.public_send(sym, *args, **kwargs, &block) }
  end

  def casecmp(other)
    return nil unless other.is_a?(Symbol)
    to_s.casecmp(other.to_s)
  end

  def casecmp?(other)
    return nil unless other.is_a?(Symbol)
    to_s.casecmp?(other.to_s)
  end

  def match(pattern, pos = :__unset__, &block)
    result = pos.equal?(:__unset__) ? to_s.match(pattern) : to_s.match(pattern, pos)
    return result unless block && !result.nil?
    block.call(result)
  end

  def match?(pattern, pos = :__unset__)
    pos.equal?(:__unset__) ? to_s.match?(pattern) : to_s.match?(pattern, pos)
  end

  def [](idx, len = :__unset__)
    len.equal?(:__unset__) ? to_s[idx] : to_s[idx, len]
  end
  alias slice []
  include Comparable
end
