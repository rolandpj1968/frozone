class String
  include Comparable

  LONG_MAX = 9_223_372_036_854_775_807 # 2**63 - 1: max C `long` on 64-bit; guards conversion to native long
  MRI_MAX_SIZE = 1_073_741_823 # 2**30 - 1: MRI's maximum string allocation size
  UPPER_A = 65
  UPPER_Z = 90
  LOWER_A = 97
  LOWER_Z = 122

  class << self
    def try_convert(obj)
      return obj if obj.is_a?(String)
      return nil unless obj.respond_to?(:to_str)
      result = obj.to_str
      raise TypeError, "can't convert #{obj.class} into String (#{obj.class}#to_str gives #{result.class})" unless result.is_a?(String) || result.nil?
      result
    end
  end

  def initialize(str = :__unset__, encoding: nil, capacity: nil)
    return self if str.equal?(:__unset__)
    raise TypeError, "no implicit conversion of #{str.class} into String" if str.nil?
    __check_frozen__
    Intrinsics.string_initialize(self, str, encoding)
    force_encoding(encoding) if encoding
    self
  end

  def %(args) = Intrinsics.string_format(self, args)
  def bytesize = Intrinsics.string_bytesize(self)
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
  def encode(enc = nil, src_enc = nil, **opts) = Intrinsics.string_encode(self, enc, src_enc, opts)
  def encode!(enc = nil, src_enc = nil, **opts) = Intrinsics.string_encode_bang(self, enc, src_enc, opts)
  # Exception duck-typing (String can be used as exception proxy)
  def message = self
  def backtrace = []
  def exception(msg = nil) = msg ? self.class.new(msg) : self
  def hash = Intrinsics.string_hash(self)
  def eql?(v) = v.is_a?(String) && self == v
  def empty? = bytesize == 0
  def lstrip = sub(/\A[[:space:]\x00]+/, '')
  def strip = lstrip.rstrip
  def tr(from, to) = Intrinsics.string_tr_raw(self, __coerce_to_str__(from), __coerce_to_str__(to))
  def squeeze(*args) = Intrinsics.string_squeeze_raw(self, *__str_args__(*args))
  def count(*args) = Intrinsics.string_count_raw(self, *__str_args__(*args))
  def delete(*args) = Intrinsics.string_delete_raw(self, *__str_args__(*args))
  def index(sub, offset = :__unset__) = Intrinsics.string_index(self, sub, offset)
  def replace(other) = Intrinsics.string_replace(self, other)
  def force_encoding(enc) = Intrinsics.string_force_encoding(self, enc)
  def valid_encoding? = Intrinsics.string_valid_encoding(self)
  def set_encoding(enc, *) = force_encoding(enc)
  def setbyte(i, b) = Intrinsics.string_setbyte(self, i, b)
  def append_as_bytes(*args) = Intrinsics.string_append_as_bytes(self, *args)
  def bytesplice(*args) = Intrinsics.string_bytesplice(self, *args)
  def scrub(replacement = nil, &block) = Intrinsics.string_scrub(self, replacement, block)
  def dump = Intrinsics.string_dump(self)
  def undump = Intrinsics.string_undump(self)
  def oct = Intrinsics.string_oct(self)
  def append_bytes(*args) = Intrinsics.string_append_bytes(self, *args)
  def unicode_normalize(form = :nfc) = Intrinsics.string_unicode_normalize(self, form)
  def unicode_normalized?(form = :nfc) = Intrinsics.string_unicode_normalized_q(self, form)
  def chr = self[0] || self
  def to_c = Intrinsics.string_to_c(self)
  def hex = to_i(16)
  def succ_bang = succ!
  alias next_bang succ_bang
  def dedup = -self
  def match?(pattern, pos = nil) = Intrinsics.string_match_q(self, pattern, pos)
  def scan(pattern, &block) = Intrinsics.string_scan(self, pattern, block)
  def chomp!(sep = :__unset__) = __bang__ { chomp(sep) }
  def chop! = __bang__ { chop }
  def strip! = __bang__ { strip }
  def lstrip! = __bang__ { lstrip }
  def rstrip! = __bang__ { rstrip }
  def upcase!(*args) = __bang__ { upcase(*args) }
  def downcase!(*args) = __bang__ { downcase(*args) }
  def capitalize!(*args) = __bang__ { capitalize(*args) }
  def squeeze!(*args) = __bang__ { squeeze(*args) }
  def delete!(*__native_args__) = __bang__ { delete(*__native_args__) }
  def swapcase!(*args) = __bang__ { swapcase(*args) }
  def tr!(from, to) = __bang__ { tr(from, to) }
  def slice!(idx, len = :__unset__) = Intrinsics.string_slice_bang(self, idx, len)
  def -@ = Intrinsics.string_dedup(self)
  def tr_s!(from, to) = __bang__ { tr_s(from, to) }
  def delete_prefix!(prefix) = __bang__ { delete_prefix(prefix) }
  def delete_suffix!(suffix) = __bang__ { delete_suffix(suffix) }
  def to_i(base = 10) = Intrinsics.string_to_i_base(self, __coerce_to_int__(base))
  def reverse = chars.reverse.join("").tap { |r| r.force_encoding(encoding) }
  def [](idx, len = :__unset__) = Intrinsics.string_slice(self, idx, len)
  alias slice []
  def b = dup.tap { |r| r.force_encoding(Encoding::BINARY) }
  def unpack(fmt, offset: nil) = Intrinsics.string_unpack(self, __coerce_to_str__(fmt), offset)
  def unpack1(fmt, offset: nil) = Intrinsics.string_unpack1(self, __coerce_to_str__(fmt), offset)
  def tr_s(from, to) = Intrinsics.string_tr_s(self, __coerce_to_str__(from), __coerce_to_str__(to))
  def include?(s) = !index(__coerce_to_str__(s)).nil?

  def ord
    raise ArgumentError, "empty string" if empty?
    enc = encoding
    b0 = getbyte(0)
    if enc == Encoding::ASCII_8BIT || enc == Encoding::ISO_8859_1
      return b0
    end
    if enc == Encoding::US_ASCII
      raise ArgumentError, "invalid byte sequence in US-ASCII" if b0 > 127
      return b0
    end
    if enc == Encoding::UTF_8
      return b0 if b0 < 128
      bs = bytesize
      if b0 >= 0xC2 && b0 < 0xE0 && bs >= 2 && (getbyte(1) & 0xC0) == 0x80
        return ((b0 & 0x1F) << 6) | (getbyte(1) & 0x3F)
      elsif b0 >= 0xE0 && b0 < 0xF0 && bs >= 3 && (getbyte(1) & 0xC0) == 0x80 && (getbyte(2) & 0xC0) == 0x80
        return ((b0 & 0x0F) << 12) | ((getbyte(1) & 0x3F) << 6) | (getbyte(2) & 0x3F)
      elsif b0 >= 0xF0 && b0 < 0xF8 && bs >= 4 && (getbyte(1) & 0xC0) == 0x80 && (getbyte(2) & 0xC0) == 0x80 && (getbyte(3) & 0xC0) == 0x80
        return ((b0 & 0x07) << 18) | ((getbyte(1) & 0x3F) << 12) | ((getbyte(2) & 0x3F) << 6) | (getbyte(3) & 0x3F)
      end
      raise ArgumentError, "invalid byte sequence in UTF-8"
    end
    # Fallback for other encodings (UTF-16, Shift_JIS, etc.)
    Intrinsics.string_ord(self)
  end

  def ascii_only?
    return false unless encoding.ascii_compatible?
    bs = bytesize
    i = 0
    while i < bs
      return false if getbyte(i) > 127
      i += 1
    end
    true
  end

  def length
    bs = bytesize
    enc = encoding
    # Single-byte encodings: length == bytesize
    if enc == Encoding::US_ASCII || enc == Encoding::ASCII_8BIT || enc == Encoding::ISO_8859_1
      return bs
    end
    if enc == Encoding::UTF_8
      # Count characters by scanning UTF-8 byte sequences with validation
      n = 0
      i = 0
      while i < bs
        b = getbyte(i)
        if b < 128
          i += 1
        elsif b >= 0xC2 && b < 0xE0
          # 2-byte: validate continuation
          if i + 1 < bs && (getbyte(i + 1) & 0xC0) == 0x80
            i += 2
          else
            i += 1  # invalid, count lead byte alone
          end
        elsif b >= 0xE0 && b < 0xF0
          # 3-byte: validate continuation and range
          if i + 2 < bs && (getbyte(i + 1) & 0xC0) == 0x80 && (getbyte(i + 2) & 0xC0) == 0x80
            b1 = getbyte(i + 1)
            if (b == 0xE0 && b1 < 0xA0) || (b == 0xED && b1 >= 0xA0)
              i += 1  # overlong or surrogate
            else
              i += 3
            end
          else
            i += 1
          end
        elsif b >= 0xF0 && b < 0xF8
          # 4-byte: validate continuation and range
          if i + 3 < bs && (getbyte(i + 1) & 0xC0) == 0x80 && (getbyte(i + 2) & 0xC0) == 0x80 && (getbyte(i + 3) & 0xC0) == 0x80
            b1 = getbyte(i + 1)
            if (b == 0xF0 && b1 < 0x90) || (b == 0xF4 && b1 >= 0x90) || b > 0xF4
              i += 1  # overlong or out of range
            else
              i += 4
            end
          else
            i += 1
          end
        else
          i += 1  # invalid byte (continuation or 0xC0/0xC1)
        end
        n += 1
      end
      return n
    end
    # Fallback: use chars for other encodings
    chars.length
  end
  alias size length

  def <=>(other)
    if other.is_a?(String)
      min_bs = bytesize < other.bytesize ? bytesize : other.bytesize
      i = 0
      while i < min_bs
        a = getbyte(i)
        b = other.getbyte(i)
        return a < b ? -1 : 1 if a != b
        i += 1
      end
      return bytesize < other.bytesize ? -1 : (bytesize > other.bytesize ? 1 : 0)
    end
    begin
      coerced = other.to_str
      return self <=> coerced if coerced.is_a?(String)
    rescue
    end
    begin
      r = other <=> self
      return nil if r.nil?
      return -r
    rescue
    end
    nil
  end


  def +(__native_v__)
    __native_v__ = __coerce_to_str__(__native_v__)
    result = String.new(self)
    result << __native_v__
    result
  end

  def *(n)
    n = __coerce_to_int__(n)
    raise RangeError, "bignum too big to convert into 'long'" if n > LONG_MAX
    raise ArgumentError, "negative string size (or exceeds maximum allowed string size)" if n < 0
    return String.new(''.force_encoding(encoding)) if empty? || n == 0
    raise ArgumentError, "argument exceeds the limit" if n > MRI_MAX_SIZE
    result = String.new(''.force_encoding(encoding))
    i = 0
    while i < n
      result << self
      i += 1
    end
    result
  end

  def <<(v)
    __check_frozen__
    if v.is_a?(Integer)
      Intrinsics.string_concat_codepoint(self, v)
    else
      Intrinsics.string_concat(self, __coerce_to_str__(v))
    end
    self
  end

  def concat(*args)
    # Snapshot all arg values before mutating self (in case self is in args)
    strs = args.map { |v| v.is_a?(String) ? v.dup : v }
    strs.each { |v| self << v }
    self
  end

  def to_s
    return self if self.class == String
    String.new(self)
  end
  alias to_str to_s

  def ==(v)
    # Must stay as intrinsic: pure-Ruby == triggers recursion because the
    # VM's constant lookup (for Intrinsics, String, etc.) uses string comparison
    # internally, creating an infinite loop. De-intrinsifying == requires the VM
    # to use a non-dispatching comparison for constant name lookups.
    return Intrinsics.string_eql(self, v) if v.is_a?(String)
    return v == self if v.respond_to?(:to_str)
    false
  end

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

  def start_with?(*prefixes)
    prefixes.each do |prefix|
      if prefix.is_a?(Regexp)
        m = Intrinsics.string_match(self, prefix)
        return true if m && m.begin(0) == 0
        next
      end
      unless prefix.is_a?(String)
        prefix = __coerce_to_str__(prefix)
      end
      return true if !prefix.empty? ? self[0, prefix.length] == prefix : true
    end
    false
  end

  def end_with?(*suffixes)
    suffixes.each do |suffix|
      unless suffix.is_a?(String)
        suffix = __coerce_to_str__(suffix)
      end
      # Raises Encoding::CompatibilityError if encodings are incompatible
      __encoding_compat__(suffix)
      if suffix.empty?
        return true
      else
        slen = suffix.length
        return true if length >= slen && self[-slen..] == suffix
      end
    end
    false
  end

  def rstrip
    begin
      sub(/[[:space:]\x00]+\z/, '')
    rescue ArgumentError => e
      raise Encoding::CompatibilityError, e.message
    end
  end

  def chomp(sep = :__unset__)
    if sep.equal?(:__unset__)
      sep = $/
    elsif sep.nil?
      return dup  # explicit nil: no-op, but still returns a copy
    else
      sep = __coerce_to_str__(sep)
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

  def reverse!
    __check_frozen__
    Intrinsics.string_replace(self, reverse)
  end

  def gsub!(pattern, replacement = :__unset__, &block)
    __check_frozen__
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
    __check_frozen__
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

  def casecmp(other)
    begin
      other = other.to_str unless other.is_a?(String)
    rescue NoMethodError, TypeError
      return nil
    end
    return nil unless other.is_a?(String)
    return nil if Encoding.compatible?(self, other).nil?
    begin
      downcase(:ascii) <=> other.downcase(:ascii)
    rescue ArgumentError
      begin
        b <=> other.b
      rescue
        nil
      end
    end
  end

  def casecmp?(other)
    begin
      other = other.to_str unless other.is_a?(String)
    rescue NoMethodError, TypeError
      return nil
    end
    return nil unless other.is_a?(String)
    return nil if Encoding.compatible?(self, other).nil?
    begin
      result = downcase(:fold) <=> other.downcase(:fold)
      result.nil? ? nil : result == 0
    rescue ArgumentError
      begin
        result = b <=> other.b
        result.nil? ? nil : result == 0
      rescue
        nil
      end
    end
  end

  def upcase(*args)
    return Intrinsics.string_upcase_opts(self, *args) unless args.empty? && ascii_only?
    __map_ascii_bytes__ { |b| __ascii_upper__(b) }
  end

  def downcase(*args)
    return Intrinsics.string_downcase_opts(self, *args) unless args.empty? && ascii_only?
    __map_ascii_bytes__ { |b| __ascii_lower__(b) }
  end

  def capitalize(*args)
    return Intrinsics.string_capitalize_opts(self, *args) unless args.empty? && ascii_only?
    return dup if empty?
    first = true
    __map_ascii_bytes__ { |b|
      if first
        first = false
        __ascii_upper__(b)
      else
        __ascii_lower__(b)
      end
    }
  end

  def swapcase(*args)
    return Intrinsics.string_swapcase_opts(self, *args) unless args.empty? && ascii_only?
    __map_ascii_bytes__ { |b|
      if b >= UPPER_A && b <= UPPER_Z
        b + 32
      elsif b >= LOWER_A && b <= LOWER_Z
        b - 32
      else
        b
      end
    }
  end

  def chars(&block)
    arr = []
    bs = bytesize
    enc = encoding
    i = 0
    if enc == Encoding::UTF_8
      while i < bs
        b = getbyte(i)
        if b < 128
          # ASCII byte -- always 1 char
          s = String.new(''.force_encoding(Encoding::BINARY))
          s << b
          s.force_encoding(enc)
          arr << s
          i += 1
        elsif b >= 0xC2 && b < 0xE0
          # 2-byte sequence (valid lead: 0xC2..0xDF)
          clen = 2
          clen = 1 if i + 1 >= bs || (getbyte(i + 1) & 0xC0) != 0x80
          s = String.new(''.force_encoding(Encoding::BINARY))
          if clen == 1
            s << b
          else
            s << b; s << getbyte(i + 1)
          end
          s.force_encoding(enc)
          arr << s
          i += clen
        elsif b >= 0xE0 && b < 0xF0
          # 3-byte sequence
          clen = 3
          if i + 2 >= bs || (getbyte(i + 1) & 0xC0) != 0x80 || (getbyte(i + 2) & 0xC0) != 0x80
            clen = 1
          else
            # Check for overlong and surrogate
            b1 = getbyte(i + 1)
            clen = 1 if b == 0xE0 && b1 < 0xA0  # overlong
            clen = 1 if b == 0xED && b1 >= 0xA0  # surrogate
          end
          s = String.new(''.force_encoding(Encoding::BINARY))
          if clen == 1
            s << b
          else
            s << b; s << getbyte(i + 1); s << getbyte(i + 2)
          end
          s.force_encoding(enc)
          arr << s
          i += clen
        elsif b >= 0xF0 && b < 0xF8
          # 4-byte sequence
          clen = 4
          if i + 3 >= bs || (getbyte(i + 1) & 0xC0) != 0x80 || (getbyte(i + 2) & 0xC0) != 0x80 || (getbyte(i + 3) & 0xC0) != 0x80
            clen = 1
          else
            b1 = getbyte(i + 1)
            clen = 1 if b == 0xF0 && b1 < 0x90  # overlong
            clen = 1 if b == 0xF4 && b1 >= 0x90  # > U+10FFFF
            clen = 1 if b > 0xF4               # > U+10FFFF
          end
          s = String.new(''.force_encoding(Encoding::BINARY))
          if clen == 1
            s << b
          else
            s << b; s << getbyte(i + 1); s << getbyte(i + 2); s << getbyte(i + 3)
          end
          s.force_encoding(enc)
          arr << s
          i += clen
        else
          # Invalid byte (continuation byte or 0xC0/0xC1) -- treat as single char
          s = String.new(''.force_encoding(Encoding::BINARY))
          s << b
          s.force_encoding(enc)
          arr << s
          i += 1
        end
      end
    elsif enc == Encoding::US_ASCII || enc == Encoding::ASCII_8BIT || enc == Encoding::ISO_8859_1
      # Single-byte encodings: one byte = one character
      while i < bs
        s = String.new(''.force_encoding(Encoding::BINARY))
        s << getbyte(i)
        s.force_encoding(enc)
        arr << s
        i += 1
      end
    else
      # Other multi-byte encodings (UTF-16, UTF-32, Shift_JIS, EUC-JP, etc.)
      # Fall back to intrinsic for correctness
      arr = Intrinsics.string_chars(self)
      return arr unless block
      arr.each(&block)
      return self
    end
    return arr unless block
    arr.each(&block)
    self
  end

  def bytes(&block)
    arr = []
    i = 0
    bs = bytesize
    while i < bs
      arr << getbyte(i)
      i += 1
    end
    return arr unless block
    arr.each(&block)
    self
  end

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

  def []=(idx, *rest)
    __check_frozen__
    # Pass `rest` as an Array (not a splat) so the box-first AOT compiler
    # can lower this call — a `*rest` SplatArg into an Intrinsics call is
    # an unhandled from_expr context. string_store unpacks the array.
    Intrinsics.string_store(self, idx, rest)
  end

  def rindex(sub, offset = :__unset__)
    if !offset.equal?(:__unset__) && offset.nil?
      raise TypeError, "no implicit conversion from nil to integer"
    end
    Intrinsics.string_rindex(self, sub, offset)
  end

  def clear
    __check_frozen__
    enc = encoding
    Intrinsics.string_replace(self, "")
    force_encoding(enc)
    self
  end

  def succ
    # Always return String (not subclass), matching MRI behaviour
    enc = encoding
    return String.new(''.force_encoding(enc)) if empty?

    result = __succ_bytes_array__

    alnum_right = __succ_find_rightmost_alnum__(result)

    if alnum_right < 0
      return __succ_carry_non_alnum__(result, enc)
    end

    leftmost_alnum = __succ_find_leftmost_alnum__(result)

    __succ_carry_alnum__(result, alnum_right, leftmost_alnum)

    result.map { |b| b.chr }.join('').force_encoding(enc)
  end
  alias next succ

  def succ!
    __check_frozen__
    Intrinsics.string_replace(self, succ)
    self
  end
  alias next! succ!

  def crypt(salt)
    salt = __coerce_to_str__(salt)
    raise ArgumentError, "crypt: NUL in crypt" if include?("\0") || salt.include?("\0")
    raise ArgumentError, "salt is too short (need >=2 chars)" if salt.length < 2
    String.new(Intrinsics.string_crypt(self, salt))
  end

  def insert(index, str)
    __check_frozen__
    index = __coerce_to_int__(index)
    str = __coerce_to_str__(str)
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

  def each_line(sep = $/, chomp: false, &block)
    sep = __coerce_to_str__(sep) if sep && !sep.is_a?(String)
    return to_enum(:each_line, sep, chomp: chomp) unless block
    raw_lines = Intrinsics.string_each_line(self, sep, nil)
    raw_lines.each do |l|
      l = chomp ? l.chomp(sep || "\n") : l
      block.call(l)
    end
    self
  end

  def lines(sep = $/, chomp: false, &block)
    sep = __coerce_to_str__(sep) if sep && !sep.is_a?(String)
    raw = Intrinsics.string_each_line(self, sep, nil)
    result = chomp ? raw.map { |l| l.chomp(sep.nil? ? "\n" : sep) } : raw
    if block
      result.each(&block)
      return self
    end
    result
  end

  def +@
    # Ruby 4.0: chilled strings (literals) return a non-chilled dup; frozen strings also dup; mutable non-chilled return self
    frozen? || Intrinsics.string_chilled_q(self) ? dup : self
  end

  def getbyte(i)
    i = __coerce_to_int__(i)
    bs = bytesize
    i += bs if i < 0
    return nil if i < 0 || i >= bs
    Intrinsics.string_get_byte(self, i)
  end

  def byteslice(idx, len = :__unset__)
    if !len.equal?(:__unset__)
      raise TypeError, "wrong argument type Range (expected Integer)" if idx.is_a?(Range)
      raise TypeError, "no implicit conversion of nil into Integer" if idx.nil? || len.nil?
    end
    Intrinsics.string_byteslice(self, idx, len)
  end

  def byteindex(sub, offset = :__unset__)
    raise TypeError, "no implicit conversion of nil into Integer" if offset.nil?
    offset.equal?(:__unset__) ? Intrinsics.string_byteindex(self, sub) : Intrinsics.string_byteindex(self, sub, offset)
  end

  def byterindex(sub, offset = :__unset__)
    raise TypeError, "no implicit conversion of nil into Integer" if offset.nil?
    offset.equal?(:__unset__) ? Intrinsics.string_byterindex(self, sub) : Intrinsics.string_byterindex(self, sub, offset)
  end

  def upto(other, exclusive = false, &block)
    other = __coerce_to_str__(other)
    return to_enum(:upto, other, exclusive) unless block
    # Pure-Ruby walk: yield self, self.succ, … while not past `other`.
    # MRI bails out when the candidate length exceeds `other` (no
    # well-defined ordering once we've gone past). Comparison is the
    # standard <=>; succ handles digit/letter carry.
    s = self
    loop do
      cmp = s <=> other
      break if cmp.nil? || cmp > 0
      break if cmp == 0 && exclusive
      yield s
      break if cmp == 0
      s = s.succ
      break if s.length > other.length
    end
    self
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

  def each_char(&block)
    return to_enum(:each_char) { length } unless block
    chars.each(&block)
    self
  end

  def each_byte(&block)
    return to_enum(:each_byte) { bytesize } unless block
    i = 0
    while i < bytesize
      block.call(getbyte(i))
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

  def center(width, padstr = ' ')
    width, padstr = __just_coerce_args__(width, padstr)
    len = length
    return dup if len >= width
    total = width - len
    left = total / 2
    right = total - left
    compat_enc = __encoding_compat__(padstr)
    lpad = __just_build_pad__(padstr, left)
    rpad = __just_build_pad__(padstr, right)
    r = lpad + self + rpad
    r.force_encoding(compat_enc) unless r.encoding == compat_enc
    r
  end

  def ljust(width, padstr = ' ')
    width, padstr = __just_coerce_args__(width, padstr)
    compat_enc = __encoding_compat__(padstr)
    len = length
    return dup if len >= width
    pad = __just_build_pad__(padstr, width - len)
    r = self + pad
    r.force_encoding(compat_enc) unless r.encoding == compat_enc
    r
  end

  def rjust(width, padstr = ' ')
    width, padstr = __just_coerce_args__(width, padstr)
    compat_enc = __encoding_compat__(padstr)
    len = length
    return dup if len >= width
    pad = __just_build_pad__(padstr, width - len)
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
      sep = __coerce_to_str__(sep)
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
      sep = __coerce_to_str__(sep)
      enc = encoding
      i = rindex(sep)
      unless i
        e = String.new(''.force_encoding(enc))
        return [e, e.dup, String.new(self)]
      end
      [String.new(self[0...i].force_encoding(enc)), String.new(sep), String.new(self[(i + sep.length)..].force_encoding(enc))]
    end
  end

  def prepend(*others)
    __check_frozen__
    prefix = others.map { |s|
      s.is_a?(String) ? s : __coerce_to_str__(s)
    }.join("")
    Intrinsics.string_replace(self, prefix + self)
    self
  end

  def delete_prefix(prefix)
    prefix = __coerce_to_str__(prefix)
    start_with?(prefix) ? self[prefix.length..] : dup
  end

  def delete_suffix(suffix)
    suffix = __coerce_to_str__(suffix)
    return dup if suffix.empty?
    end_with?(suffix) ? self[0...(length - suffix.length)] : dup
  end

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
    bits = __coerce_to_int__(bits)
    total = bytes.reduce(0) { |s, b| s + b }
    bits <= 0 ? total : total % (1 << bits)
  end

  private

  # Pure byte check: all bytes <= 127. Does NOT check encoding compatibility
  # (avoids recursion through Encoding#ascii_compatible? -> Set#include? -> String#==).
  def __bytes_ascii__?
    bs = bytesize
    i = 0
    while i < bs
      return false if getbyte(i) > 127
      i += 1
    end
    true
  end

  def __str_args__(*args) = args.map { |a| __coerce_to_str__(a) }
  def __ascii_upper__(b) = (b >= LOWER_A && b <= LOWER_Z) ? b - 32 : b
  def __ascii_lower__(b) = (b >= UPPER_A && b <= UPPER_Z) ? b + 32 : b
  # Bytes are already copied by the intrinsic; skip Kernel's frozen check.
  def initialize_copy(source) = self
  # Build a pad string of exactly +total+ characters by repeating +padstr+.
  def __just_build_pad__(padstr, total) = (padstr * ((total / padstr.length) + 1))[0, total]

  # Map each character's first byte through a block, rebuild the string.
  def __map_ascii_bytes__
    enc = encoding
    chars.map { |c| yield(c.getbyte(0)).chr(enc) }.join("").force_encoding(enc)
  end

  # Return compatible Encoding for self and other, or raise Encoding::CompatibilityError.
  def __encoding_compat__(other)
    enc = Encoding.compatible?(self, other)
    raise Encoding::CompatibilityError, "incompatible character encodings: #{encoding} and #{other.encoding}" if enc.nil?
    enc
  end

  def __bang__
    __check_frozen__
    r = yield
    return nil if r == self
    Intrinsics.string_replace(self, r)
  end

  # Return the string's bytes as a mutable Array of integers.
  def __succ_bytes_array__
    bs = bytesize
    result = []
    i = 0
    while i < bs
      result << getbyte(i)
      i += 1
    end
    result
  end
  # Return the index of the rightmost alphanumeric byte, or -1 if none.
  def __succ_find_rightmost_alnum__(bytes)
    j = bytes.length - 1
    while j >= 0
      b = bytes[j]
      return j if (b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122)
      j -= 1
    end
    -1
  end
  # Return the index of the leftmost alphanumeric byte (caller guarantees one exists).
  def __succ_find_leftmost_alnum__(bytes)
    j = 0
    while j < bytes.length
      b = bytes[j]
      return j if (b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122)
      j += 1
    end
    0
  end
  # Handle the no-alphanumeric case: plain byte-level carry from the right.
  # Mutates +bytes+ in place (or prepends 0x01), then returns a new String.
  def __succ_carry_non_alnum__(bytes, enc)
    carry = true
    j = bytes.length - 1
    while carry && j >= 0
      b = bytes[j]
      if b < 255
        bytes[j] = b + 1
        carry = false
      else
        bytes[j] = 0
        j -= 1
      end
    end
    bytes.unshift(1) if carry
    bytes.map { |b| b.chr }.join('').force_encoding(enc)
  end
  # Perform the alphanumeric carry pass starting at +alnum_right+.
  # Mutates +bytes+ in place, inserting a carry character before +leftmost_alnum+ if needed.
  def __succ_carry_alnum__(bytes, alnum_right, leftmost_alnum)
    carry = true
    j = alnum_right
    while carry && j >= 0
      b = bytes[j]
      if b >= 48 && b <= 57         # '0'..'9'
        if b < 57
          bytes[j] = b + 1
          carry = false
        else
          bytes[j] = 48             # wrap to '0'
          j -= 1
          j -= 1 while j >= 0 && !((bytes[j] >= 48 && bytes[j] <= 57) || (bytes[j] >= 65 && bytes[j] <= 90) || (bytes[j] >= 97 && bytes[j] <= 122))
        end
      elsif b >= 65 && b <= 90      # 'A'..'Z'
        if b < 90
          bytes[j] = b + 1
          carry = false
        else
          bytes[j] = 65             # wrap to 'A'
          j -= 1
          j -= 1 while j >= 0 && !((bytes[j] >= 48 && bytes[j] <= 57) || (bytes[j] >= 65 && bytes[j] <= 90) || (bytes[j] >= 97 && bytes[j] <= 122))
        end
      elsif b >= 97 && b <= 122     # 'a'..'z'
        if b < 122
          bytes[j] = b + 1
          carry = false
        else
          bytes[j] = 97             # wrap to 'a'
          j -= 1
          j -= 1 while j >= 0 && !((bytes[j] >= 48 && bytes[j] <= 57) || (bytes[j] >= 65 && bytes[j] <= 90) || (bytes[j] >= 97 && bytes[j] <= 122))
        end
      else
        carry = false
      end
    end

    return unless carry

    # Prepend carry character matching the class of the leftmost alnum
    b0 = bytes[leftmost_alnum]
    carry_byte = if b0 >= 48 && b0 <= 57
      49   # '1'
    elsif b0 >= 65 && b0 <= 90
      65   # 'A'
    else
      97   # 'a'
    end
    bytes.insert(leftmost_alnum, carry_byte)
  end
  # Coerce and validate the width and padstr arguments shared by ljust/rjust/center.
  def __just_coerce_args__(width, padstr)
    width = __coerce_to_int__(width)
    padstr = __coerce_to_str__(padstr)
    raise ArgumentError, "zero width padding" if padstr.empty?
    [width, padstr]
  end
end
