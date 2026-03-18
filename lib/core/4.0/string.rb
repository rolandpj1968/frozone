class String
  include Comparable

  def self.try_convert(obj)
    return obj if obj.is_a?(String)
    return nil unless obj.respond_to?(:to_str)
    result = obj.to_str
    raise TypeError, "can't convert #{obj.class} into String (#{obj.class}#to_str gives #{result.class})" unless result.is_a?(String) || result.nil?
    result
  end

  def initialize(str = :__unset__, encoding: nil, capacity: nil)
    return self if str.equal?(:__unset__)
    raise TypeError, "no implicit conversion of #{str.class} into String" if str.nil?
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    Intrinsics.string_initialize(self, str, encoding)
    force_encoding(encoding) if encoding
    self
  end

  def +(v)
    unless v.is_a?(String)
      raise TypeError, "no implicit conversion of #{v.class} into String" unless v.respond_to?(:to_str)
      v = v.to_str
      raise TypeError, "to_str must return String (#{v.class} given)" unless v.is_a?(String)
    end
    result = String.new(self)
    result << v
    result
  end
  def *(n)
    n = n.to_int unless n.is_a?(Integer)
    raise RangeError, "bignum too big to convert into 'long'" if n > 9_223_372_036_854_775_807
    raise ArgumentError, "negative string size (or exceeds maximum allowed string size)" if n < 0
    return String.new(''.force_encoding(encoding)) if empty? || n == 0
    raise ArgumentError, "argument exceeds the limit" if n > 1_073_741_823
    result = String.new(''.force_encoding(encoding))
    i = 0
    while i < n
      result << self
      i += 1
    end
    result
  end
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
  def length = chars.length
  alias size length
  def bytesize = Intrinsics.string_bytesize(self)
  def to_s
    return self if self.class == String
    String.new(self)
  end

  alias to_str to_s
  def to_i(base = 0)
    base = base.to_int unless base.is_a?(Integer)
    Intrinsics.string_to_i_base(self, base)
  end
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
  def encode(enc = nil, src_enc = nil, **opts)
    Intrinsics.string_encode(self, enc, src_enc, opts)
  end

  def encode!(enc = nil, src_enc = nil, **opts)
    Intrinsics.string_encode_bang(self, enc, src_enc, opts)
  end

  def <=>(v) = Intrinsics.string_spaceship(self, v)
  def ==(v)
    return Intrinsics.string_eql(self, v) if v.is_a?(String)
    return v == self if v.respond_to?(:to_str)
    false
  end

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
    elsif pattern.is_a?(Regexp)
      str = pos.equal?(:__unset__) ? self : self[pos..] || ''
      result = pattern.match(str)
    elsif pattern.respond_to?(:to_str)
      pattern = pattern.to_str
      raise TypeError, "no implicit conversion of #{pattern.class} into String" unless pattern.is_a?(String)
      result = pos.equal?(:__unset__) ? Intrinsics.string_match(self, pattern) : Intrinsics.string_match_pos(self, pattern, pos)
    else
      raise TypeError, "no implicit conversion of #{pattern.class} into String"
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

  def empty? = bytesize == 0

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
      return true if !prefix.empty? ? self[0, prefix.length] == prefix : true
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
      # Raises Encoding::CompatibilityError if encodings are incompatible
      Intrinsics.string_encoding_compat(self, suffix)
      if suffix.empty?
        return true
      else
        slen = suffix.length
        return true if length >= slen && self[-slen..] == suffix
      end
    end
    false
  end

  def include?(s)
    unless s.is_a?(String)
      raise TypeError, "no implicit conversion of #{s.class} into String" unless s.respond_to?(:to_str)
      s = s.to_str
      raise TypeError, "can't convert to String" unless s.is_a?(String)
    end
    !index(s).nil?
  end
  def lstrip = sub(/\A[[:space:]\x00]+/, '')

  def rstrip
    begin
      sub(/[[:space:]\x00]+\z/, '')
    rescue ArgumentError => e
      raise Encoding::CompatibilityError, e.message
    end
  end

  def strip = lstrip.rstrip
  def chomp(sep = :__unset__)
    if sep.equal?(:__unset__)
      sep = $/
    elsif sep.nil?
      return dup  # explicit nil: no-op, but still returns a copy
    else
      sep = sep.to_str unless sep.is_a?(String)
    end
    return dup if empty?
    if sep.nil?
      # Default separator (from $/ being nil): no-op
      return dup
    elsif sep == ''
      # Paragraph mode: remove all trailing newlines (including \r\n sequences)
      result = dup
      while result.end_with?("\n")
        len = result.length
        if len >= 2 && result[len - 2] == "\r"
          result = result[0...(len - 2)]
        else
          result = result[0...(len - 1)]
        end
      end
      result
    elsif sep == "\n"
      # Default newline mode: remove one trailing \r\n, \r, or \n
      # Use encode for cross-encoding comparison (e.g. UTF-32BE strings with "\n")
      lf = "\n".encode(encoding) rescue "\n"
      cr = "\r".encode(encoding) rescue "\r"
      crlf = "\r\n".encode(encoding) rescue "\r\n"
      len = length
      if len >= 2 && end_with?(crlf)
        self[0...(len - 2)]
      elsif end_with?(cr) || end_with?(lf)
        self[0...(len - 1)]
      else
        dup
      end
    else
      # Remove sep from end if present
      end_with?(sep) ? self[0...(length - sep.length)] : dup
    end
  end

  def chomp!(sep = :__unset__)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = chomp(sep.equal?(:__unset__) ? :__unset__ : sep)
    return nil if r.equal?(self) || r == self
    Intrinsics.string_replace(self, r)
  end

  def chop
    return dup if empty?
    len = length
    crlf = begin; "\r\n".encode(encoding); rescue; "\r\n"; end
    if len >= 2 && end_with?(crlf)
      self[0...(len - 2)]
    else
      self[0...(len - 1)]
    end
  end

  def chop!
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    return nil if empty?; r = chop; Intrinsics.string_replace(self, r)
  end

  def strip!
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = strip; return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def lstrip!
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = lstrip; return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def rstrip!
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = rstrip; return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def upcase!(*args)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = upcase(*args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def downcase!(*args)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = downcase(*args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def capitalize!(*args)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = capitalize(*args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def reverse!
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    Intrinsics.string_replace(self, reverse)
  end

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
      snap = bytesize
      r = Intrinsics.string_sub(self, pattern, nil, block)
      raise RuntimeError, "string modified" if bytesize != snap
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
    r = squeeze(*args); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def delete!(*args)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = delete(*args); return nil if r == self; Intrinsics.string_replace(self, r)
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
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    r = swapcase(*args); return nil if r == self; Intrinsics.string_replace(self, r)
  end
  def reverse
    r = chars.reverse.join
    r.force_encoding(encoding)
    r
  end
  def chars(&block)
    arr = Intrinsics.string_chars(self)
    return arr unless block
    arr.each(&block)
    self
  end

  def bytes(&block)
    arr = []
    i = 0
    while i < bytesize
      arr << Intrinsics.string_get_byte(self, i)
      i += 1
    end
    return arr unless block
    arr.each(&block)
    self
  end
  def ord = Intrinsics.string_ord(self)
  def split(sep = nil, limit = :__unset__, &block)
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
    r = tr(from, to); return nil if r == self; Intrinsics.string_replace(self, r)
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
  def index(sub, offset = :__unset__) = Intrinsics.string_index(self, sub, offset)

  def rindex(sub, offset = :__unset__)
    if !offset.equal?(:__unset__) && offset.nil?
      raise TypeError, "no implicit conversion from nil to integer"
    end
    Intrinsics.string_rindex(self, sub, offset)
  end
  def replace(other) = Intrinsics.string_replace(self, other)

  def clear
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    enc = encoding
    Intrinsics.string_replace(self, "")
    force_encoding(enc)
    self
  end
  def succ = Intrinsics.string_succ(self)
  alias next succ
  def succ!
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    Intrinsics.string_succ_bang(self)
  end

  alias next! succ!

  def crypt(salt)
    unless salt.is_a?(String)
      raise TypeError, "no implicit conversion of #{salt.class} into String" unless salt.respond_to?(:to_str)
      salt = salt.to_str
      raise TypeError, "can't convert to String" unless salt.is_a?(String)
    end
    raise ArgumentError, "crypt: NUL in crypt" if include?("\0") || salt.include?("\0")
    raise ArgumentError, "salt is too short (need >=2 chars)" if salt.length < 2
    String.new(Intrinsics.string_crypt(self, salt))
  end

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
    len = length
    idx = index
    if idx < 0
      idx = len + idx + 1
      raise IndexError, "index #{index} out of string" if idx < 0
    else
      raise IndexError, "index #{index} out of string" if idx > len
    end
    new_str = self[0...idx].to_s + str + (idx < len ? self[idx..].to_s : '')
    Intrinsics.string_replace(self, new_str)
    self
  end
  def slice!(idx, len = :__unset__)
    len.equal?(:__unset__) ? Intrinsics.string_slice_bang(self, idx) : Intrinsics.string_slice_bang(self, idx, len)
  end

  def each_line(sep = $/, chomp: false, &block)
    if sep && !sep.is_a?(String)
      raise TypeError, "no implicit conversion of #{sep.class} into String" unless sep.respond_to?(:to_str)
      sep = sep.to_str
      raise TypeError, "can't convert to String" unless sep.is_a?(String)
    end
    return to_enum(:each_line, sep, chomp: chomp) unless block
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
  def b
    r = dup
    r.force_encoding(Encoding::BINARY)
    r
  end

  def +@
    # Ruby 4.0: chilled strings (literals) return a non-chilled dup; frozen strings also dup; mutable non-chilled return self
    frozen? || Intrinsics.string_chilled_q(self) ? dup : self
  end
  def -@
    Intrinsics.string_dedup(self)
  end

  def force_encoding(enc) = Intrinsics.string_force_encoding(self, enc)
  def valid_encoding? = Intrinsics.string_valid_encoding(self)
  def ascii_only? = Intrinsics.string_ascii_only(self)
  def set_encoding(enc, *) = force_encoding(enc)

  def unpack(fmt, offset: nil)
    unless fmt.is_a?(String)
      raise TypeError, "no implicit conversion of #{fmt.class} into String" unless fmt.respond_to?(:to_str)
      fmt = fmt.to_str
      raise TypeError, "can't convert to String" unless fmt.is_a?(String)
    end
    Intrinsics.string_unpack(self, fmt, offset)
  end

  def unpack1(fmt, offset: nil)
    unless fmt.is_a?(String)
      raise TypeError, "no implicit conversion of #{fmt.class} into String" unless fmt.respond_to?(:to_str)
      fmt = fmt.to_str
      raise TypeError, "can't convert to String" unless fmt.is_a?(String)
    end
    Intrinsics.string_unpack1(self, fmt, offset)
  end

  def getbyte(i)
    unless i.is_a?(Integer)
      raise TypeError, "no implicit conversion of #{i.class} into Integer" unless i.respond_to?(:to_int)
      i = i.to_int
      raise TypeError, "can't convert to Integer" unless i.is_a?(Integer)
    end
    bs = bytesize
    i += bs if i < 0
    return nil if i < 0 || i >= bs
    Intrinsics.string_get_byte(self, i)
  end
  def setbyte(i, b) = Intrinsics.string_setbyte(self, i, b)
  def append_as_bytes(*args) = Intrinsics.string_append_as_bytes(self, *args)

  def byteslice(idx, len = :__unset__)
    if !len.equal?(:__unset__) && idx.is_a?(Range)
      raise TypeError, "wrong argument type Range (expected Integer)"
    end
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

  def tr_s(from, to)
    from = from.to_str unless from.is_a?(String)
    to = to.to_str unless to.is_a?(String)
    Intrinsics.string_tr_s(self, from, to)
  end

  def tr_s!(from, to)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    from = from.to_str unless from.is_a?(String)
    to = to.to_str unless to.is_a?(String)
    r = tr_s(from, to); return nil if r == self; Intrinsics.string_replace(self, r)
  end

  def grapheme_clusters(&block)
    result = Intrinsics.string_grapheme_clusters(self)
    return result unless block
    result.each(&block)
    self
  end

  def each_grapheme_cluster(&block)
    return to_enum(:each_grapheme_cluster) { grapheme_clusters.size } unless block
    grapheme_clusters.each(&block)
    self
  end

  def append_bytes(*args) = Intrinsics.string_append_bytes(self, *args)

  def unicode_normalize(form = :nfc) = Intrinsics.string_unicode_normalize(self, form)
  def unicode_normalized?(form = :nfc) = Intrinsics.string_unicode_normalized_q(self, form)

  def each_char(&block)
    return to_enum(:each_char) { length } unless block
    chars.each(&block)
    self
  end

  def each_byte(&block)
    return to_enum(:each_byte) { bytesize } unless block
    i = 0
    while i < bytesize
      block.call(Intrinsics.string_get_byte(self, i))
      i += 1
    end
    self
  end

  def each_codepoint(&block)
    return to_enum(:each_codepoint) { length } unless block
    chars.each { |c| block.call(c.ord) }
    self
  end

  def codepoints(&block)
    arr = chars.map(&:ord)
    return arr unless block
    arr.each(&block)
    self
  end

  def chr = self[0] || self

  def center(width, padstr = ' ')
    unless width.is_a?(Integer)
      raise TypeError, "no implicit conversion of #{width.class} into Integer" unless width.respond_to?(:to_int)
      width = width.to_int
      raise TypeError, "can't convert to Integer" unless width.is_a?(Integer)
    end
    unless padstr.is_a?(String)
      raise TypeError, "no implicit conversion of #{padstr.class} into String" unless padstr.respond_to?(:to_str)
      padstr = padstr.to_str
      raise TypeError, "can't convert to String" unless padstr.is_a?(String)
    end
    raise ArgumentError, "zero width padding" if padstr.empty?
    len = length
    return dup if len >= width
    total = width - len
    left = total / 2
    right = total - left
    compat_enc = Intrinsics.string_encoding_compat(self, padstr)
    lpad = (padstr * ((left / padstr.length) + 1))[0, left]
    rpad = (padstr * ((right / padstr.length) + 1))[0, right]
    r = lpad + self + rpad
    r.force_encoding(compat_enc) unless r.encoding == compat_enc
    r
  end

  def ljust(width, padstr = ' ')
    unless width.is_a?(Integer)
      raise TypeError, "no implicit conversion of #{width.class} into Integer" unless width.respond_to?(:to_int)
      width = width.to_int
      raise TypeError, "can't convert to Integer" unless width.is_a?(Integer)
    end
    unless padstr.is_a?(String)
      raise TypeError, "no implicit conversion of #{padstr.class} into String" unless padstr.respond_to?(:to_str)
      padstr = padstr.to_str
      raise TypeError, "can't convert to String" unless padstr.is_a?(String)
    end
    raise ArgumentError, "zero width padding" if padstr.empty?
    compat_enc = Intrinsics.string_encoding_compat(self, padstr)
    len = length
    return dup if len >= width
    total = width - len
    pad = (padstr * ((total / padstr.length) + 1))[0, total]
    r = self + pad
    r.force_encoding(compat_enc) unless r.encoding == compat_enc
    r
  end

  def rjust(width, padstr = ' ')
    unless width.is_a?(Integer)
      raise TypeError, "no implicit conversion of #{width.class} into Integer" unless width.respond_to?(:to_int)
      width = width.to_int
      raise TypeError, "can't convert to Integer" unless width.is_a?(Integer)
    end
    unless padstr.is_a?(String)
      raise TypeError, "no implicit conversion of #{padstr.class} into String" unless padstr.respond_to?(:to_str)
      padstr = padstr.to_str
      raise TypeError, "can't convert to String" unless padstr.is_a?(String)
    end
    raise ArgumentError, "zero width padding" if padstr.empty?
    compat_enc = Intrinsics.string_encoding_compat(self, padstr)
    len = length
    return dup if len >= width
    total = width - len
    pad = (padstr * ((total / padstr.length) + 1))[0, total]
    r = pad + self
    r.force_encoding(compat_enc) unless r.encoding == compat_enc
    r
  end

  def partition(sep)
    if sep.is_a?(Regexp)
      m = match(sep)
      unless m
        enc = encoding
        return [String.new(self), ''.force_encoding(enc), ''.force_encoding(enc)]
      end
      ms = m.begin(0)
      me = m.end(0)
      [String.new(self[0...ms]), String.new(self[ms...me]), String.new(self[me..] || '')]
    else
      unless sep.is_a?(String)
        raise TypeError, "no implicit conversion of #{sep.class} into String" unless sep.respond_to?(:to_str)
        sep = sep.to_str
        raise TypeError, "can't convert to String" unless sep.is_a?(String)
      end
      i = index(sep)
      unless i
        enc = encoding
        return [String.new(self), ''.force_encoding(enc), ''.force_encoding(enc)]
      end
      [String.new(self[0...i]), String.new(sep), String.new(self[(i + sep.length)..] || '')]
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
        raise TypeError, "no implicit conversion of #{sep.class} into String" unless sep.respond_to?(:to_str)
        sep = sep.to_str
        raise TypeError, "can't convert to String" unless sep.is_a?(String)
      end
      enc = encoding
      i = rindex(sep)
      unless i
        e = String.new(''.force_encoding(enc))
        return [e, e.dup, String.new(self)]
      end
      [String.new(self[0...i].force_encoding(enc)), String.new(sep), String.new(self[(i + sep.length)..].force_encoding(enc))]
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
    start_with?(prefix) ? self[prefix.length..] : dup
  end

  def delete_prefix!(prefix)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    prefix = prefix.to_str unless prefix.is_a?(String)
    return nil if prefix.empty? || !start_with?(prefix)
    Intrinsics.string_replace(self, self[prefix.length..])
  end

  def delete_suffix(suffix)
    suffix = suffix.to_str unless suffix.is_a?(String)
    return dup if suffix.empty?
    end_with?(suffix) ? self[0...(length - suffix.length)] : dup
  end

  def delete_suffix!(suffix)
    raise FrozenError, "can't modify frozen String: #{inspect}" if frozen?
    suffix = suffix.to_str unless suffix.is_a?(String)
    return nil if suffix.empty? || !end_with?(suffix)
    Intrinsics.string_replace(self, self[0...(length - suffix.length)])
  end

  def dedup = -self

  def scrub!(replacement = nil, &block)
    r = scrub(replacement, &block)
    return nil if r == self
    Intrinsics.string_replace(self, r)
  end

  def unicode_normalize!(form = :nfc)
    Intrinsics.string_replace(self, unicode_normalize(form))
    self
  end

  def sum(bits = 16)
    bits = bits.to_int unless bits.is_a?(Integer)
    total = bytes.reduce(0) { |s, b| s + b }
    bits <= 0 ? total : total % (1 << bits)
  end

end

class Regexp
  def =~(str) = Intrinsics.regexp_match_index(self, str)
  def !~(str) = !(self =~ str)
  def match(str, pos = nil) = Intrinsics.regexp_match(self, str)
  def match?(str) = !Intrinsics.regexp_match(self, str).nil?
  def ===(str) = !(self =~ str).nil?
end
