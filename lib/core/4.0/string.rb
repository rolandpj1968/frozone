class String
  include Comparable

  def self.try_convert(obj)
    return obj if obj.is_a?(String)
    return nil unless obj.respond_to?(:to_str)
    result = obj.to_str
    raise TypeError, "can't convert #{obj.class} into String (#{obj.class}#to_str gives #{result.class})" unless result.is_a?(String) || result.nil?
    result
  end

  def initialize(str = nil, encoding: nil, capacity: nil)
    return self if str.nil?
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    Intrinsics.string_initialize(self, str, encoding)
    self
  end

  def +(v) = Intrinsics.string_plus(self, v)
  def *(n) = Intrinsics.string_multiply(self, n)
  def %(args) = Intrinsics.string_format(self, args)
  def <<(v)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    if v.is_a?(Integer)
      Intrinsics.string_concat_codepoint(self, v)
    elsif v.is_a?(String)
      Intrinsics.string_concat(self, v)
    else
      unless v.respond_to?(:to_str)
        raise TypeError, "no implicit conversion of #{v.class} into String"
      end
      str = v.to_str
      raise TypeError, "no implicit conversion of #{v.class} into String" unless str.is_a?(String)
      Intrinsics.string_concat(self, str)
    end
    self
  end

  def concat(*args)
    # Snapshot all arg values before mutating self (in case self is in args)
    strs = args.map { |v| v.is_a?(String) ? v.dup : v }
    strs.each { |v| self << v }
    self
  end
  def length = Intrinsics.string_length(self)
  alias size length
  def bytesize = Intrinsics.string_bytesize(self)
  def to_s = Intrinsics.string_to_s(self)
  def to_i(base = 0) = base == 0 ? Intrinsics.string_to_i(self) : Intrinsics.string_to_i_base(self, base)
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
  def encode(enc = nil, src_enc = nil, **opts) = Intrinsics.string_encode(self, enc, src_enc)
  def encode!(enc = nil, src_enc = nil, **opts) = Intrinsics.string_encode_bang(self, enc, src_enc)

  def <=>(v) = Intrinsics.string_spaceship(self, v)
  def ==(v) = Intrinsics.string_eql(self, v)

  # Exception duck-typing (String can be used as exception proxy)
  def message = self
  def backtrace = []
  def exception(msg = nil) = msg ? self.class.new(msg) : self

  def hash = Intrinsics.string_hash(self)
  def eql?(v) = Intrinsics.string_eql(self, v)
  def =~(pattern)
    raise TypeError, "type mismatch: String given" if pattern.is_a?(String)
    return pattern =~ self unless pattern.is_a?(Regexp)
    Intrinsics.regexp_match_index(pattern, self)
  end

  def match(pattern, pos = :__unset__, &block)
    if pattern.is_a?(String)
      result = pos.equal?(:__unset__) ? Intrinsics.string_match(self, pattern) : Intrinsics.string_match_pos(self, pattern, pos)
    else
      # Dispatch match on pattern object (allows mocking/overriding)
      str = pos.equal?(:__unset__) ? self : self[pos..] || ''
      result = pattern.match(str)
    end
    return result unless block && !result.nil?
    block.call(result)
  end

  def match?(pattern, pos = :__unset__)
    if pos.equal?(:__unset__)
      Intrinsics.string_match_q(self, pattern, nil)
    else
      Intrinsics.string_match_q(self, pattern, pos)
    end
  end
  def scan(pattern, &block)
    Intrinsics.string_scan(self, pattern, block)
  end

  def empty? = Intrinsics.string_empty(self)
  def start_with?(*prefixes)
    prefixes.each do |prefix|
      if prefix.is_a?(Regexp)
        m = Intrinsics.string_match(self, prefix)
        return true if m && m.begin(0) == 0
        next
      end
      unless prefix.is_a?(String)
        begin
          prefix = prefix.to_str
        rescue NoMethodError
          raise TypeError, "no implicit conversion of #{prefix.class} into String"
        end
      end
      return true if Intrinsics.string_start_with(self, prefix)
    end
    false
  end

  def end_with?(*suffixes)
    suffixes.each do |suffix|
      unless suffix.is_a?(String)
        begin
          suffix = suffix.to_str
        rescue NoMethodError
          raise TypeError, "no implicit conversion of #{suffix.class} into String"
        end
      end
      return true if Intrinsics.string_end_with(self, suffix)
    end
    false
  end
  def include?(s) = Intrinsics.string_include(self, s)
  def strip = Intrinsics.string_strip(self)
  def lstrip = Intrinsics.string_lstrip(self)
  def rstrip = Intrinsics.string_rstrip(self)
  def chomp(sep = :__unset__)
    if sep.equal?(:__unset__)
      sep = $/
    elsif sep.nil?
      return self  # explicit nil: no-op
    else
      sep = sep.to_str unless sep.is_a?(String)
    end
    Intrinsics.string_chomp(self, sep)
  end

  def chomp!(sep = :__unset__)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = chomp(sep.equal?(:__unset__) ? :__unset__ : sep)
    return nil if r.equal?(self) || r == self
    Intrinsics.string_replace(self, r)
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
    r = Intrinsics.string_upcase_opts(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def downcase!(*args)
    r = Intrinsics.string_downcase_opts(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def capitalize!(*args)
    r = Intrinsics.string_capitalize_opts(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def reverse! = Intrinsics.string_reverse_bang(self)

  def gsub!(pattern, replacement = :__unset__, &block)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    if replacement.equal?(:__unset__)
      return to_enum(:gsub!, pattern) unless block
      r = Intrinsics.string_gsub(self, pattern, nil, block)
    else
      r = Intrinsics.string_gsub(self, pattern, replacement, block)
    end
    return nil if r.nil? || r.is_a?(NilClass)
    changed = r != self
    Intrinsics.string_replace(self, r)
    changed ? self : nil
  end

  def sub!(pattern, replacement = :__unset__, &block)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    if replacement.equal?(:__unset__)
      raise ArgumentError, "wrong number of arguments (given 1, expected 2)" unless block
      r = Intrinsics.string_sub(self, pattern, nil, block)
    else
      r = Intrinsics.string_sub(self, pattern, replacement, block)
    end
    return nil if r.nil? || r.is_a?(NilClass)
    changed = r != self
    Intrinsics.string_replace(self, r)
    changed ? self : nil
  end

  def squeeze!(*args)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = Intrinsics.string_squeeze(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def delete!(*args)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = Intrinsics.string_delete(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end
  def casecmp(other)
    begin
      other = other.to_str unless other.is_a?(String)
    rescue NoMethodError, TypeError
      return nil
    end
    return nil unless other.is_a?(String)
    Intrinsics.string_casecmp(self, other)
  end

  def casecmp?(other)
    begin
      other = other.to_str unless other.is_a?(String)
    rescue NoMethodError, TypeError
      return nil
    end
    return nil unless other.is_a?(String)
    Intrinsics.string_casecmp_q(self, other)
  end
  def upcase(*args) = Intrinsics.string_upcase_opts(self, *args)
  def downcase(*args) = Intrinsics.string_downcase_opts(self, *args)
  def capitalize(*args) = Intrinsics.string_capitalize_opts(self, *args)
  def swapcase(*args) = Intrinsics.string_swapcase_opts(self, *args)
  def swapcase!(*args)
    r = Intrinsics.string_swapcase_opts(self, *args); return nil if r == self; Intrinsics.string_replace(self, r)
  end
  def reverse = Intrinsics.string_reverse(self)
  def chars = Intrinsics.string_chars(self)
  def bytes = Intrinsics.string_bytes(self)
  def ord = Intrinsics.string_ord(self)
  def split(sep = nil, limit = nil, &block)
    if sep.nil? && $; && !Fiber[:__split_warn_guard__]
      Fiber[:__split_warn_guard__] = true
      begin
        warn "warning: $; is set to non-nil value"
      ensure
        Fiber[:__split_warn_guard__] = nil
      end
    end
    result = Intrinsics.string_split(self, sep, limit)
    if block
      result.each { |s| block.call(s) }
      return self
    end
    result
  end
  def gsub(pattern, replacement = :__unset__, &block)
    if replacement.equal?(:__unset__)
      return to_enum(:gsub, pattern) unless block
      Intrinsics.string_gsub(self, pattern, nil, block)
    else
      Intrinsics.string_gsub(self, pattern, replacement, block)
    end
  end

  def sub(pattern, replacement = :__unset__, &block)
    if replacement.equal?(:__unset__)
      raise ArgumentError, "wrong number of arguments (given 1, expected 2)" unless block
      Intrinsics.string_sub(self, pattern, nil, block)
    else
      Intrinsics.string_sub(self, pattern, replacement, block)
    end
  end
  def tr(from, to) = Intrinsics.string_tr(self, from, to)
  def tr!(from, to)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = Intrinsics.string_tr(self, from, to); return nil if r == self; Intrinsics.string_replace(self, r)
  end
  def squeeze(*args) = Intrinsics.string_squeeze(self, *args)
  def count(*args) = Intrinsics.string_count(self, *args)
  def delete(*args) = Intrinsics.string_delete(self, *args)
  def [](idx, len = :__unset__)
    len.equal?(:__unset__) ? Intrinsics.string_slice(self, idx) : Intrinsics.string_slice(self, idx, len)
  end
  alias slice []

  def []=(idx, *rest)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    Intrinsics.string_store(self, idx, *rest)
  end
  def index(sub, offset = nil) = Intrinsics.string_index(self, sub, offset)
  def rindex(sub, offset = nil) = Intrinsics.string_rindex(self, sub, offset)
  def replace(other) = Intrinsics.string_replace(self, other)

  def clear
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    Intrinsics.string_replace(self, "")
    self
  end
  def succ = Intrinsics.string_succ(self)
  alias next succ
  def succ! = Intrinsics.string_succ_bang(self)
  alias next! succ!
  def insert(index, str)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    index = index.to_int unless index.is_a?(Integer)
    unless str.is_a?(String)
      begin
        str = str.to_str
      rescue NoMethodError
        raise TypeError, "no implicit conversion of #{str.class} into String"
      end
      raise TypeError, "no implicit conversion of #{str.class} into String" unless str.is_a?(String)
    end
    Intrinsics.string_insert(self, index, str)
  end
  def slice!(idx, len = :__unset__)
    len.equal?(:__unset__) ? Intrinsics.string_slice_bang(self, idx) : Intrinsics.string_slice_bang(self, idx, len)
  end

  def each_line(sep = $/, chomp: false, &block)
    return to_enum(:each_line, sep, chomp: chomp) unless block
    if sep && !sep.is_a?(String)
      begin
        sep = sep.to_str
      rescue NoMethodError
        raise TypeError, "no implicit conversion of #{sep.class} into String"
      end
      raise TypeError, "no implicit conversion of #{sep.class} into String" unless sep.is_a?(String)
    end
    raw_lines = Intrinsics.string_each_line(self, sep, nil)
    raw_lines.each do |l|
      l = chomp ? l.chomp(sep || "\n") : l
      block.call(l)
    end
    self
  end

  def lines(sep = $/, chomp: false, &block)
    if sep && !sep.is_a?(String)
      begin
        sep = sep.to_str
      rescue NoMethodError
        raise TypeError, "no implicit conversion of #{sep.class} into String"
      end
      raise TypeError, "no implicit conversion of #{sep.class} into String" unless sep.is_a?(String)
    end
    raw = Intrinsics.string_each_line(self, sep, nil)
    result = chomp ? raw.map { |l| l.chomp(sep.nil? ? "\n" : sep) } : raw
    if block
      result.each(&block)
      return self
    end
    result
  end
  def b = Intrinsics.string_b(self)
  def +@ = dup
  def -@
    Intrinsics.string_dedup(self)
  end

  def force_encoding(enc) = Intrinsics.string_force_encoding(self, enc)
  def valid_encoding? = Intrinsics.string_valid_encoding(self)
  def ascii_only? = Intrinsics.string_ascii_only(self)
  def set_encoding(enc, *) = force_encoding(enc)

  def getbyte(i) = Intrinsics.string_getbyte(self, i)
  def setbyte(i, b) = Intrinsics.string_setbyte(self, i, b)
  def append_as_bytes(*args) = Intrinsics.string_append_as_bytes(self, *args)

  def byteslice(idx, len = :__unset__)
    len.equal?(:__unset__) ? Intrinsics.string_byteslice(self, idx) : Intrinsics.string_byteslice(self, idx, len)
  end

  def byteindex(sub, offset = :__unset__)
    raise TypeError, "no implicit conversion of nil into Integer" if offset.nil?
    offset.equal?(:__unset__) ? Intrinsics.string_byteindex(self, sub) : Intrinsics.string_byteindex(self, sub, offset)
  end

  def byterindex(sub, offset = :__unset__)
    raise TypeError, "no implicit conversion of nil into Integer" if offset.nil?
    offset.equal?(:__unset__) ? Intrinsics.string_byterindex(self, sub) : Intrinsics.string_byterindex(self, sub, offset)
  end

  def bytesplice(*args) = Intrinsics.string_bytesplice(self, *args)

  def scrub(replacement = nil, &block) = Intrinsics.string_scrub(self, replacement, block)
  def dump = Intrinsics.string_dump(self)
  def undump = Intrinsics.string_undump(self)
  def oct = Intrinsics.string_oct(self)

  def upto(other, exclusive = false, &block)
    unless other.is_a?(String)
      begin
        other = other.to_str
      rescue NoMethodError, TypeError
        raise TypeError, "no implicit conversion of #{other.class} into String"
      end
      raise TypeError, "no implicit conversion of #{other.class} into String" unless other.is_a?(String)
    end
    return to_enum(:upto, other, exclusive) unless block
    Intrinsics.string_upto(self, other, exclusive, block)
  end

  def tr_s(from, to) = Intrinsics.string_tr_s(self, from, to)

  def tr_s!(from, to)
    r = Intrinsics.string_tr_s(self, from, to); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def grapheme_clusters(&block)
    result = Intrinsics.string_grapheme_clusters(self)
    return result unless block
    result.each(&block)
    self
  end

  def each_grapheme_cluster(&block)
    Intrinsics.string_each_grapheme_cluster(self, block)
  end

  def append_bytes(*args) = Intrinsics.string_append_bytes(self, *args)

  def unicode_normalize(form = :nfc) = Intrinsics.string_unicode_normalize(self, form)
  def unicode_normalized?(form = :nfc) = Intrinsics.string_unicode_normalized_q(self, form)

  def each_char(&block)
    return to_enum(:each_char) unless block
    chars.each(&block)
    self
  end

  def each_byte(&block)
    return to_enum(:each_byte) unless block
    bytes.each(&block)
    self
  end

  def each_codepoint(&block)
    return to_enum(:each_codepoint) unless block
    chars.each { |c| block.call(c.ord) }
    self
  end

  def codepoints
    chars.map(&:ord)
  end

  def chr = self[0] || self

  def center(width, padstr = ' ')
    width = width.to_int unless width.is_a?(Integer)
    padstr = padstr.to_str unless padstr.is_a?(String)
    raise ArgumentError, "zero width padding" if padstr.empty?
    len = length
    return dup if len >= width
    total = width - len
    left = total / 2
    right = total - left
    lpad = (padstr * ((left / padstr.length) + 1))[0, left]
    rpad = (padstr * ((right / padstr.length) + 1))[0, right]
    r = lpad + self + rpad
    r.force_encoding(encoding) if r.encoding != encoding
    r
  end

  def ljust(width, padstr = ' ')
    width = width.to_int unless width.is_a?(Integer)
    padstr = padstr.to_str unless padstr.is_a?(String)
    raise ArgumentError, "zero width padding" if padstr.empty?
    len = length
    return dup if len >= width
    total = width - len
    pad = (padstr * ((total / padstr.length) + 1))[0, total]
    self + pad
  end

  def rjust(width, padstr = ' ')
    width = width.to_int unless width.is_a?(Integer)
    padstr = padstr.to_str unless padstr.is_a?(String)
    raise ArgumentError, "zero width padding" if padstr.empty?
    len = length
    return dup if len >= width
    total = width - len
    pad = (padstr * ((total / padstr.length) + 1))[0, total]
    pad + self
  end

  def partition(sep)
    if sep.is_a?(Regexp)
      m = match(sep)
      return [self, '', ''] unless m
      ms = m.begin(0)
      me = m.end(0)
      [self[0...ms], self[ms...me], self[me..] || '']
    else
      sep = sep.to_str unless sep.is_a?(String)
      i = index(sep)
      return [self, '', ''] unless i
      [self[0...i], sep, self[(i + sep.length)..] || '']
    end
  end

  def rpartition(sep)
    if sep.is_a?(Regexp)
      # Find the rightmost match by scanning all positions from right to left
      last_pos = nil
      last_len = nil
      # Try matching at each position from length-1 down to 0
      pos = length
      while pos >= 0
        m = Intrinsics.string_match(self[pos..] || '', sep)
        if m && m.begin(0) == 0
          # match at this position
          last_pos = pos
          last_len = m[0].length
          break
        end
        pos -= 1
      end
      return [String.new(''), String.new(''), String.new(self)] unless last_pos
      [String.new(self[0...last_pos] || ''), String.new(self[last_pos, last_len] || ''), String.new(self[(last_pos + last_len)..] || '')]
    else
      unless sep.is_a?(String)
        begin
          sep = sep.to_str
        rescue NoMethodError
          raise TypeError, "no implicit conversion of #{sep.class} into String"
        end
        raise TypeError, "no implicit conversion of #{sep.class} into String" unless sep.is_a?(String)
      end
      enc = encoding
      i = rindex(sep)
      unless i
        e = ''.force_encoding(enc)
        return [e.dup, e.dup, dup]
      end
      [self[0...i].force_encoding(enc), sep.dup, self[(i + sep.length)..].force_encoding(enc)]
    end
  end

  def to_c = Intrinsics.string_to_c(self)

  def hex = to_i(16)

  def succ_bang = succ!
  alias next_bang succ_bang

  def prepend(*others)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    prefix = others.map do |s|
      next s if s.is_a?(String)
      begin
        r = s.to_str
      rescue NoMethodError
        raise TypeError, "no implicit conversion of #{s.class} into String"
      end
      raise TypeError, "no implicit conversion of #{s.class} into String" unless r.is_a?(String)
      r
    end.join
    Intrinsics.string_replace(self, prefix + self)
    self
  end

  def delete_prefix(prefix)
    prefix = prefix.to_str unless prefix.is_a?(String)
    start_with?(prefix) ? self[prefix.length..] : self
  end

  def delete_prefix!(prefix)
    prefix = prefix.to_str unless prefix.is_a?(String)
    return nil unless start_with?(prefix)
    Intrinsics.string_replace(self, self[prefix.length..])
  end

  def delete_suffix(suffix)
    suffix = suffix.to_str unless suffix.is_a?(String)
    return self if suffix.empty?
    end_with?(suffix) ? self[0...(length - suffix.length)] : self
  end

  def delete_suffix!(suffix)
    suffix = suffix.to_str unless suffix.is_a?(String)
    return nil if suffix.empty? || !end_with?(suffix)
    Intrinsics.string_replace(self, self[0...(length - suffix.length)])
  end

  def dedup = -self

  def scrub!(replacement = nil, &block)
    r = Intrinsics.string_scrub(self, replacement, block)
    return nil if r == self
    Intrinsics.string_replace(self, r)
  end

  def unicode_normalize!(form = :nfc) = (r = Intrinsics.string_unicode_normalize(self, form); Intrinsics.string_replace(self, r); self)

  def sum(bits = 16)
    total = bytes.reduce(0) { |s, b| s + b }
    bits == 0 ? total : total % (1 << bits)
  end

end

class Regexp
  def =~(str) = Intrinsics.regexp_match_index(self, str)
  def !~(str) = !(self =~ str)
  def match(str, pos = nil) = Intrinsics.regexp_match(self, str)
  def match?(str) = !Intrinsics.regexp_match(self, str).nil?
  def ===(str) = !(self =~ str).nil?
end
