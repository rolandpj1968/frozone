class Symbol
  include Comparable

  def to_s = Intrinsics.symbol_to_s(self)
  alias id2name to_s
  def name = to_s.freeze
  def to_sym = self
  alias intern to_sym
  def inspect = ":#{to_s}"
  def hash = Intrinsics.symbol_hash(self)
  def eql?(v) = self == v
  # Symbols are interned (Intrinsics.symbol -> unique pointer per name),
  # so identity == equality. Symbol#hash is identity-based too -- if two
  # Symbol instances ever bypassed interning, hash/eql? would already be
  # broken, so a to_s fallback wouldn't help. Just identity.
  def ==(v) = equal?(v)
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
  def casecmp(other) = other.is_a?(Symbol) ? to_s.casecmp(other.to_s) : nil
  def casecmp?(other) = other.is_a?(Symbol) ? to_s.casecmp?(other.to_s) : nil
  def match?(pattern, pos = :__unset__) = pos.equal?(:__unset__) ? to_s.match?(pattern) : to_s.match?(pattern, pos)
  def [](idx, len = :__unset__) = len.equal?(:__unset__) ? to_s[idx] : to_s[idx, len]
  alias slice []
  def self.allocate = raise TypeError, "allocating an instance of Symbol"
  def self.new(*) = raise NoMethodError, "undefined method 'new' for Symbol:Class"
  def self.all_symbols = Intrinsics.symbol_all_symbols

  def to_proc
    sym = self
    pr = ->(obj, *args, **kwargs, &block) { obj.public_send(sym, *args, **kwargs, &block) }
    Intrinsics.proc_set_parameters_override(pr, [[:req], [:rest]])
    Intrinsics.proc_set_symbol_name(pr, sym)
    pr
  end

  def match(pattern, pos = :__unset__, &block)
    result = pos.equal?(:__unset__) ? to_s.match(pattern) : to_s.match(pattern, pos)
    return result unless block && !result.nil?
    block.call(result)
  end
end
