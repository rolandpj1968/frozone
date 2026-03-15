class String
  def initialize(str = nil, encoding: nil, capacity: nil)
    Intrinsics.string_initialize(self, str, encoding) unless str.nil?
  end

  def +(v) = Intrinsics.string_plus(self, v)
  def *(n) = Intrinsics.string_multiply(self, n)
  def %(args) = Intrinsics.string_format(self, args)
  def <<(v) = Intrinsics.string_concat(self, v)
  def concat(*args); args.each { |v| Intrinsics.string_concat(self, v) }; self; end
  def length = Intrinsics.string_length(self)
  alias size length
  def bytesize = Intrinsics.string_bytesize(self)
  def to_s = Intrinsics.string_to_s(self)
  def to_i = Intrinsics.string_to_i(self)
  def to_f = Intrinsics.string_to_f(self)
  def to_r = Intrinsics.string_to_r(self)
  def to_sym = Intrinsics.string_to_sym(self)
  alias intern to_sym
  def inspect = Intrinsics.string_inspect(self)
  def dup = Intrinsics.string_dup(self)
  def clone(freeze: nil) = Intrinsics.string_clone(self, freeze)
  def freeze = Intrinsics.string_freeze(self)
  def frozen? = Intrinsics.string_frozen(self)
  def encoding = Intrinsics.string_encoding(self)
  def encode(enc = nil) = Intrinsics.string_encode(self, enc)

  def <=>(v) = Intrinsics.string_spaceship(self, v)
  def ==(v) = Intrinsics.string_eql(self, v)

  # Exception duck-typing (String can be used as exception proxy)
  def message = self
  def backtrace = []
  def exception(msg = nil) = msg ? self.class.new(msg) : self

  def hash = Intrinsics.string_hash(self)
  def eql?(v) = Intrinsics.string_eql(self, v)
  def =~(pattern) = Intrinsics.regexp_match_index(pattern, self)
  def match(pattern) = Intrinsics.string_match(self, pattern)
  def scan(pattern) = Intrinsics.string_scan(self, pattern)

  def empty? = Intrinsics.string_empty(self)
  def start_with?(*args) = Intrinsics.string_start_with(self, *args)
  def end_with?(*args) = Intrinsics.string_end_with(self, *args)
  def include?(s) = Intrinsics.string_include(self, s)
  def strip = Intrinsics.string_strip(self)
  def lstrip = Intrinsics.string_lstrip(self)
  def rstrip = Intrinsics.string_rstrip(self)
  def chomp(sep = nil) = Intrinsics.string_chomp(self, sep)
  def chomp!(sep = nil)
    r = Intrinsics.string_chomp(self, sep); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def chop = Intrinsics.string_chop(self)

  def chop!
    return nil if empty?; r = Intrinsics.string_chop(self); Intrinsics.string_replace(self, r)
  end

  def strip!
    r = Intrinsics.string_strip(self); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def lstrip!
    r = Intrinsics.string_lstrip(self); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def rstrip!
    r = Intrinsics.string_rstrip(self); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def upcase!(*args)
    r = Intrinsics.string_upcase(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def downcase!(*args)
    r = Intrinsics.string_downcase(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def capitalize!(*args)
    r = Intrinsics.string_capitalize(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def reverse! = Intrinsics.string_reverse_bang(self)

  def gsub!(pattern, replacement = nil, &block)
    r = Intrinsics.string_gsub(self, pattern, replacement, block)
    return nil if r.nil? || r.is_a?(NilClass)
    changed = r != self
    Intrinsics.string_replace(self, r)
    changed ? self : nil
  end

  def sub!(pattern, replacement = nil, &block)
    r = Intrinsics.string_sub(self, pattern, replacement, block)
    return nil if r.nil? || r.is_a?(NilClass)
    changed = r != self
    Intrinsics.string_replace(self, r)
    changed ? self : nil
  end

  def squeeze!(*args)
    r = Intrinsics.string_squeeze(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def delete!(*args)
    r = Intrinsics.string_delete(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end
  def casecmp(other) = upcase <=> other.upcase
  def casecmp?(other) = casecmp(other) == 0
  def upcase = Intrinsics.string_upcase(self)
  def downcase = Intrinsics.string_downcase(self)
  def capitalize = Intrinsics.string_capitalize(self)
  def reverse = Intrinsics.string_reverse(self)
  def chars = Intrinsics.string_chars(self)
  def bytes = Intrinsics.string_bytes(self)
  def ord = Intrinsics.string_ord(self)
  def split(sep = nil, limit = nil) = Intrinsics.string_split(self, sep, limit)
  def gsub(pattern, replacement = nil, &block) = Intrinsics.string_gsub(self, pattern, replacement, block)
  def sub(pattern, replacement = nil, &block) = Intrinsics.string_sub(self, pattern, replacement, block)
  def tr(from, to) = Intrinsics.string_tr(self, from, to)
  def squeeze(*args) = Intrinsics.string_squeeze(self, *args)
  def count(*args) = Intrinsics.string_count(self, *args)
  def delete(*args) = Intrinsics.string_delete(self, *args)
  def [](idx, len = nil) = Intrinsics.string_slice(self, idx, len)
  alias slice []
  def index(sub, offset = nil) = Intrinsics.string_index(self, sub, offset)
  def rindex(sub, offset = nil) = Intrinsics.string_rindex(self, sub, offset)
  def replace(other) = Intrinsics.string_replace(self, other)
  def succ = Intrinsics.string_succ(self)
  alias next succ
  def succ! = Intrinsics.string_succ_bang(self)
  alias next! succ!
  def insert(index, str) = Intrinsics.string_insert(self, index, str)
  def slice!(idx, len = nil) = Intrinsics.string_slice_bang(self, idx, len)

  def each_line(sep = "\n", &block) = Intrinsics.string_each_line(self, sep, block)
  def lines(sep = "\n") = each_line(sep)
  def b = Intrinsics.string_b(self)
  def +@ = dup
  def -@ = freeze
  def force_encoding(enc) = Intrinsics.string_force_encoding(self, enc)
  def valid_encoding? = true
  def ascii_only? = false
  def set_encoding(enc) = self
end

class Regexp
  def =~(str) = Intrinsics.regexp_match_index(self, str)
  def !~(str) = !(self =~ str)
  def match(str, pos = nil) = Intrinsics.regexp_match(self, str)
  def match?(str) = !Intrinsics.regexp_match(self, str).nil?
  def ===(str) = !(self =~ str).nil?
end
