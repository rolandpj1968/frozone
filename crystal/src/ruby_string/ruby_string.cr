# RubyString — Crystal implementation of Ruby string semantics.
#
# Design decision: CLASS not struct.
#
# Ruby strings are mutable reference objects. Crystal structs are value types:
# every assignment copies the value, and mutating methods require the receiver
# to be a mutable variable. That mismatch makes structs awkward here because
# two variables pointing at "the same" string would not share mutations —
# exactly the opposite of Ruby semantics. Using a class gives us reference
# semantics: `a = b` makes both names point to the same object, and
# `a.concat_bytes!(x)` is visible through `b`, matching Ruby behaviour.
#
# Encoding compatibility for `+` and `==`:
#   MRI rule: two strings are "encoding-compatible" for concatenation if one
#   of them is ASCII-only (all bytes < 0x80) — in that case the non-ASCII
#   encoding wins. If both are non-ASCII and have different encodings, an
#   Encoding::CompatibilityError is raised.
#
# Bytes are ALWAYS raw byte storage. Crystal's String cannot be used here
# because it enforces valid UTF-8. We carry raw Bytes + a RubyEncoding tag.

require "../ruby_object"
require "../encoding/single_byte_transcoder"

# ---------------------------------------------------------------------------
# Exception raised when mutating a frozen RubyString
# ---------------------------------------------------------------------------

class RubyFrozenError < Exception
  def initialize(msg : String = "can't modify frozen String: \"...\"")
    super(msg)
  end
end

# ---------------------------------------------------------------------------
# RubyString
# ---------------------------------------------------------------------------

class RubyString < RubyObject
  include Comparable(RubyString)

  # ------------------------------------------------------------------
  # Flag bit positions in @flags : UInt8
  # ------------------------------------------------------------------
  FROZEN_BIT           =  0_u8
  CHILLED_BIT          =  1_u8
  ASCII_ONLY_VALID_BIT =  2_u8  # cached result is populated
  ASCII_ONLY_BIT       =  3_u8  # cached value
  VALID_ENC_VALID_BIT  =  4_u8  # cached result is populated
  VALID_ENC_BIT        =  5_u8  # cached value

  # Mask covering all cache bits (bits 2-5); cleared on any mutation.
  CACHE_MASK = (1_u8 << ASCII_ONLY_VALID_BIT) |
               (1_u8 << ASCII_ONLY_BIT)        |
               (1_u8 << VALID_ENC_VALID_BIT)   |
               (1_u8 << VALID_ENC_BIT)

  # ------------------------------------------------------------------
  # Storage
  # ------------------------------------------------------------------

  @bytes    : Bytes
  @encoding : RubyEncoding
  @flags    : UInt8

  # ------------------------------------------------------------------
  # Constructors
  # ------------------------------------------------------------------

  # Primary initializer: take a Bytes slice, an encoding, and optional flags.
  # The slice is *copied* so the caller's buffer cannot alias our storage.
  # flags defaults to 0 (no frozen, no chilled, no cached values).
  def initialize(bytes : Bytes, encoding : RubyEncoding, flags : UInt8 = 0_u8)
    @bytes    = bytes.dup
    @encoding = encoding
    @flags    = flags & ~CACHE_MASK  # never inherit stale cache from caller
  end

  # Construct from a Crystal String (assumed to be valid UTF-8).
  # Stores the raw UTF-8 bytes without transcoding.
  # The encoding tag defaults to UTF_8 but can be overridden (force_encoding semantics).
  def initialize(str : String, encoding : RubyEncoding = RubyEncoding::UTF_8)
    @bytes    = str.to_slice.dup
    @encoding = encoding
    @flags    = 0_u8
  end

  # ------------------------------------------------------------------
  # Class-level factories
  # ------------------------------------------------------------------

  # Construct from a Crystal String.  The string's UTF-8 bytes are stored
  # as-is; the encoding tag defaults to UTF_8 unless overridden.
  def self.from_string(s : String, encoding : RubyEncoding = RubyEncoding::UTF_8) : RubyString
    new(s.to_slice, encoding)
  end

  # Empty string with the given encoding.
  def self.empty(encoding : RubyEncoding = RubyEncoding::UTF_8) : RubyString
    new(Bytes.empty, encoding)
  end

  # Single-byte string.  Defaults to ASCII_8BIT because a lone byte has no
  # meaningful higher encoding context.
  def self.from_byte(b : UInt8, encoding : RubyEncoding = RubyEncoding::ASCII_8BIT) : RubyString
    new(Bytes[b], encoding)
  end

  # Convenience factory: always ASCII-8BIT encoding.
  def self.new_ascii_8bit(bytes : Bytes) : RubyString
    new(bytes, RubyEncoding::ASCII_8BIT)
  end

  # Convenience factory: from a Crystal String (valid UTF-8), tagged UTF-8.
  def self.new_utf8(str : String) : RubyString
    new(str.to_slice, RubyEncoding::UTF_8)
  end

  # ------------------------------------------------------------------
  # Flag helpers (private)
  # ------------------------------------------------------------------

  private def flag?(bit : UInt8) : Bool
    (@flags & (1_u8 << bit)) != 0_u8
  end

  private def set_flag!(bit : UInt8) : Nil
    @flags |= (1_u8 << bit)
  end

  private def clear_flag!(bit : UInt8) : Nil
    @flags &= ~(1_u8 << bit)
  end

  private def clear_caches! : Nil
    @flags &= ~CACHE_MASK
  end

  private def check_frozen! : Nil
    raise RubyFrozenError.new if frozen?
  end

  # ------------------------------------------------------------------
  # Basic properties
  # ------------------------------------------------------------------

  def bytesize : Int32
    @bytes.size
  end

  def empty? : Bool
    @bytes.size == 0
  end

  def encoding : RubyEncoding
    @encoding
  end

  def frozen? : Bool
    flag?(FROZEN_BIT)
  end

  def chilled? : Bool
    flag?(CHILLED_BIT)
  end

  # Character count (number of characters, NOT bytes).
  # For single-byte encodings or ASCII-only strings this equals bytesize.
  # For multi-byte encodings the non-ASCII path is stubbed.
  def length : Int32
    if @encoding.single_byte? || ascii_only?
      @bytes.size
    else
      raise NotImplementedError.new(
        "multi-byte char count not yet implemented for #{@encoding.name}")
    end
  end

  # Alias for `length`.
  def size : Int32
    length
  end

  # ------------------------------------------------------------------
  # Byte access
  # ------------------------------------------------------------------

  # Returns the byte value at index i as Int32, or -1 if out of range.
  # Supports negative indices (Ruby semantics: -1 = last byte).
  def get_byte(i : Int32) : Int32
    idx = i < 0 ? @bytes.size + i : i
    return -1 if idx < 0 || idx >= @bytes.size
    @bytes[idx].to_i32
  end

  # Returns the byte at index i as UInt8?, or nil if out of range.
  def getbyte(i : Int32) : UInt8?
    idx = i < 0 ? @bytes.size + i : i
    return nil if idx < 0 || idx >= @bytes.size
    @bytes[idx]
  end

  # Set a byte at index i.  Clears encoding caches.
  # Raises RubyFrozenError if frozen, IndexError if out of range.
  # Returns the byte value written.
  def set_byte!(i : Int32, b : UInt8) : UInt8
    check_frozen!
    idx = i < 0 ? @bytes.size + i : i
    raise IndexError.new("index #{i} out of string") if idx < 0 || idx >= @bytes.size
    @bytes[idx] = b
    clear_caches!
    b
  end

  # Set a byte at index i (public API name matching Ruby's String#setbyte).
  # Raises RubyFrozenError if frozen, IndexError if out of range.
  # Returns the byte value written.
  def setbyte(i : Int32, b : UInt8) : UInt8
    set_byte!(i, b)
  end

  # ------------------------------------------------------------------
  # Mutation
  # ------------------------------------------------------------------

  # Append the bytes of *other* to self in-place.
  # Raises RubyFrozenError if frozen.
  # Returns self.
  def concat_bytes!(other : RubyString) : RubyString
    check_frozen!
    new_bytes = Bytes.new(@bytes.size + other.@bytes.size)
    @bytes.copy_to(new_bytes)
    other.@bytes.copy_to(new_bytes + @bytes.size)
    @bytes = new_bytes
    clear_caches!
    self
  end

  # Change encoding tag without touching the bytes (in-place).
  # Raises RubyFrozenError if frozen.
  # Returns self.
  def force_encoding!(enc : RubyEncoding) : RubyString
    check_frozen!
    @encoding = enc
    clear_caches!
    self
  end

  # Return a new RubyString with the same bytes but a different encoding tag.
  # Does NOT transcode. Clears cached flags on the new object.
  def force_encoding(enc : RubyEncoding) : RubyString
    RubyString.new(@bytes, enc)
  end

  # Transcode to a different encoding.
  # Stub — full transcoding is not yet implemented.
  def encode(to : RubyEncoding) : RubyString
    raise NotImplementedError.new("encoding conversion not yet implemented")
  end

  # Replace content in-place (bytes and encoding) from *other*.
  # Raises RubyFrozenError if frozen.
  # Returns self.
  def replace!(other : RubyString) : RubyString
    check_frozen!
    @bytes    = other.@bytes.dup
    @encoding = other.@encoding
    clear_caches!
    self
  end

  # ------------------------------------------------------------------
  # Encoding queries — lazy cached
  # ------------------------------------------------------------------

  # Returns true if all characters in the string are ASCII (codepoints < 128).
  #
  # ASCII_8BIT / US_ASCII: scan for any byte > 127.
  # UTF_8: additionally verify the bytes form valid UTF-8 (a string with
  # invalid UTF-8 sequences is not "ascii only" even if bytes happen to be
  # all < 128, because it is not a valid string).
  # Other encodings: scan bytes (best-effort; full table validation deferred).
  def ascii_only? : Bool
    if flag?(ASCII_ONLY_VALID_BIT)
      return flag?(ASCII_ONLY_BIT)
    end

    result = compute_ascii_only
    set_flag!(ASCII_ONLY_VALID_BIT)
    if result
      set_flag!(ASCII_ONLY_BIT)
    else
      clear_flag!(ASCII_ONLY_BIT)
    end
    result
  end

  # Returns true if the bytes form a valid sequence for the declared encoding.
  #
  # ASCII_8BIT: always true (it is a raw byte container).
  # US_ASCII:   all bytes <= 127.
  # UTF_8:      valid UTF-8 sequences.
  # Single-byte encodings: delegate to Encoding::SingleByte transcoder.
  # Others:     stubbed true (full validation needs conversion tables).
  def valid_encoding? : Bool
    if flag?(VALID_ENC_VALID_BIT)
      return flag?(VALID_ENC_BIT)
    end

    result = compute_valid_encoding
    set_flag!(VALID_ENC_VALID_BIT)
    if result
      set_flag!(VALID_ENC_BIT)
    else
      clear_flag!(VALID_ENC_BIT)
    end
    result
  end

  # ------------------------------------------------------------------
  # Freezing / duplication
  # ------------------------------------------------------------------

  # Mark this string as frozen.  Returns self.
  def freeze! : RubyString
    set_flag!(FROZEN_BIT)
    self
  end

  # Return a new, unfrozen, unchilled copy of this string.
  def dup : RubyString
    RubyString.new(@bytes, @encoding, 0_u8)
  end

  # ------------------------------------------------------------------
  # Operators
  # ------------------------------------------------------------------

  # Concatenate two RubyStrings.
  # Encoding rules (matching MRI):
  #   - Both ASCII_8BIT  → result is ASCII_8BIT
  #   - One is ascii_only? → result takes the other's encoding
  #   - Both same encoding → that encoding
  #   - Otherwise → raise Encoding::CompatibilityError
  def +(other : RubyString) : RubyString
    enc = compatible_encoding_for_concat(other)
    new_bytes = Bytes.new(@bytes.size + other.@bytes.size)
    @bytes.copy_to(new_bytes)
    other.@bytes.copy_to(new_bytes + @bytes.size)
    RubyString.new(new_bytes, enc)
  end

  # Repeat the string n times.
  def *(n : Int32) : RubyString
    return RubyString.new(Bytes.empty, @encoding) if n <= 0
    new_bytes = Bytes.new(@bytes.size * n)
    n.times do |i|
      @bytes.copy_to(new_bytes + (i * @bytes.size))
    end
    RubyString.new(new_bytes, @encoding)
  end

  # ------------------------------------------------------------------
  # Comparison
  # ------------------------------------------------------------------

  # Ruby eql? semantics: same bytes AND same encoding.
  def ==(other : RubyString) : Bool
    @encoding == other.@encoding && @bytes == other.@bytes
  end

  def ==(other : RubyObject) : Bool
    false
  end

  # Ruby == semantics: ASCII-only strings compare equal regardless of encoding.
  # Two strings are equal if:
  #   - Their bytes are identical AND their encodings are the same, OR
  #   - Both are ASCII-only and their bytes are identical (encoding agnostic).
  def ruby_eql?(other : RubyString) : Bool
    return false unless @bytes == other.@bytes
    return true if @encoding == other.@encoding
    # Bytes are equal; check if both are ASCII-only (encoding-compatible).
    ascii_only? && other.ascii_only?
  end

  # Spaceship on raw bytes (lexicographic byte order).
  # Returns nil if encodings are incompatible (non-ASCII content, different encodings).
  def <=>(other : RubyString) : Int32?
    # Encoding compatibility check: if both are non-ASCII and different encodings, incomparable.
    unless encodings_compatible_for_compare?(other)
      return nil
    end
    bytesize_compare(other)
  end

  # Lexicographic compare on raw bytes (always returns Int32, ignores encoding).
  def bytesize_compare(other : RubyString) : Int32
    min_size = Math.min(@bytes.size, other.@bytes.size)
    0.upto(min_size - 1) do |i|
      cmp = @bytes[i].to_i32 - other.@bytes[i].to_i32
      return cmp if cmp != 0
    end
    @bytes.size - other.@bytes.size
  end

  # ------------------------------------------------------------------
  # Conversion
  # ------------------------------------------------------------------

  # Best-effort conversion to a Crystal String (UTF-8).
  # Invalid bytes are replaced with the UTF-8 replacement character U+FFFD.
  def to_crystal_string : String
    case @encoding
    when RubyEncoding::UTF_8, RubyEncoding::US_ASCII
      scrub_utf8(@bytes)
    when RubyEncoding::ASCII_8BIT
      # Treat each byte as latin-1 / ISO-8859-1; non-ASCII become U+0080..U+00FF
      String.build do |io|
        @bytes.each do |b|
          if b < 0x80_u8
            io.write_byte(b)
          else
            # Encode the codepoint (b as U+00xx) in UTF-8: two-byte sequence
            io.write_byte(0xC0_u8 | (b >> 6))
            io.write_byte(0x80_u8 | (b & 0x3F_u8))
          end
        end
      end
    else
      # For other encodings, do a best-effort UTF-8 scrub of the raw bytes.
      scrub_utf8(@bytes)
    end
  end

  # to_s delegates to to_crystal_string.
  # TODO: For invalid UTF-8, Crystal's String.new may raise. We scrub above to
  # avoid that, but scrubbing means lossy conversion. A future `to_s` overload
  # should respect the encoding more carefully.
  def to_s : String
    to_crystal_string
  end

  # Ruby-style inspect: double-quoted with escape sequences.
  # Handles the full ASCII printable range; non-ASCII bytes are hex-escaped.
  def inspect : String
    String.build do |io|
      io << '"'
      @bytes.each do |b|
        case b
        when 0x22_u8 then io << "\\\""  # "
        when 0x5C_u8 then io << "\\\\"  # \
        when 0x07_u8 then io << "\\a"
        when 0x08_u8 then io << "\\b"
        when 0x09_u8 then io << "\\t"
        when 0x0A_u8 then io << "\\n"
        when 0x0B_u8 then io << "\\v"
        when 0x0C_u8 then io << "\\f"
        when 0x0D_u8 then io << "\\r"
        when 0x1B_u8 then io << "\\e"
        when 0x20_u8..0x7E_u8
          # printable ASCII (space through tilde, excluding \ and ")
          io.write_byte(b)
        else
          # Non-printable or non-ASCII: hex escape
          io << "\\x"
          io << b.to_s(16).upcase.rjust(2, '0')
        end
      end
      io << '"'
    end
  end

  # Return a copy of the underlying raw bytes.
  def raw_bytes : Bytes
    @bytes.dup
  end

  # ------------------------------------------------------------------
  # Private: encoding compatibility helpers
  # ------------------------------------------------------------------

  private def compatible_encoding_for_concat(other : RubyString) : RubyEncoding
    a_enc = @encoding
    b_enc = other.@encoding

    return RubyEncoding::ASCII_8BIT if a_enc == RubyEncoding::ASCII_8BIT &&
                                       b_enc == RubyEncoding::ASCII_8BIT
    return b_enc if ascii_only?
    return a_enc if other.ascii_only?
    return a_enc if a_enc == b_enc

    raise "Encoding::CompatibilityError: incompatible character encodings: " \
          "#{a_enc.name} and #{b_enc.name}"
  end

  private def encodings_compatible_for_compare?(other : RubyString) : Bool
    return true if @encoding == other.@encoding
    return true if ascii_only? || other.ascii_only?
    false
  end

  # ------------------------------------------------------------------
  # Private: encoding computation
  # ------------------------------------------------------------------

  private def compute_ascii_only : Bool
    case @encoding
    when RubyEncoding::ASCII_8BIT, RubyEncoding::US_ASCII
      all_bytes_ascii?
    when RubyEncoding::UTF_8
      # Must be valid UTF-8 AND all codepoints < 128 (for valid UTF-8,
      # all-ASCII codepoints means all bytes < 128).
      valid_utf8? && all_bytes_ascii?
    else
      # Best-effort: byte scan
      all_bytes_ascii?
    end
  end

  private def compute_valid_encoding : Bool
    case @encoding
    when RubyEncoding::ASCII_8BIT
      true
    when RubyEncoding::US_ASCII
      all_bytes_ascii?
    when RubyEncoding::UTF_8
      valid_utf8?
    else
      if @encoding.single_byte?
        valid_single_byte?
      else
        # Multi-byte encodings other than UTF-8: stub as true.
        # TODO: implement validation for EUC-JP, Shift_JIS, GB18030, etc.
        true
      end
    end
  end

  private def all_bytes_ascii? : Bool
    @bytes.each do |b|
      return false if b > 127_u8
    end
    true
  end

  # Validate that all bytes are defined in the single-byte encoding's table.
  # Uses the Encoding::SingleByte transcoder (returns -1 for undefined bytes).
  private def valid_single_byte? : Bool
    # Derive the canonical table key used by single_byte_transcoder.
    # The transcoder uses keys like "ISO-8859-1", "WINDOWS-1252", "KOI8-R", etc.
    enc_name = @encoding.name
    @bytes.each do |b|
      return false if Encoding::SingleByte.byte_to_ucs(b, enc_name) == -1
    end
    true
  end

  # Simple UTF-8 validator using a state machine.
  #
  # UTF-8 byte patterns:
  #   0xxxxxxx                                    — 1-byte (U+0000..U+007F)
  #   110xxxxx 10xxxxxx                           — 2-byte (U+0080..U+07FF)
  #   1110xxxx 10xxxxxx 10xxxxxx                  — 3-byte (U+0800..U+FFFF)
  #   11110xxx 10xxxxxx 10xxxxxx 10xxxxxx         — 4-byte (U+10000..U+10FFFF)
  #
  # Rejects: overlong encodings, surrogate halves (U+D800..U+DFFF),
  # codepoints above U+10FFFF, and unexpected continuation bytes.
  private def valid_utf8? : Bool
    i = 0
    while i < @bytes.size
      b = @bytes[i]
      if b < 0x80_u8
        i += 1
      elsif b < 0xC0_u8
        return false
      elsif b < 0xE0_u8
        return false if i + 1 >= @bytes.size
        return false unless continuation?(@bytes[i + 1])
        return false if b < 0xC2_u8
        i += 2
      elsif b < 0xF0_u8
        return false if i + 2 >= @bytes.size
        return false unless continuation?(@bytes[i + 1]) && continuation?(@bytes[i + 2])
        if b == 0xE0_u8
          return false if @bytes[i + 1] < 0xA0_u8
        end
        if b == 0xED_u8
          return false if @bytes[i + 1] >= 0xA0_u8
        end
        i += 3
      elsif b < 0xF8_u8
        return false if i + 3 >= @bytes.size
        return false unless continuation?(@bytes[i + 1]) &&
                            continuation?(@bytes[i + 2]) &&
                            continuation?(@bytes[i + 3])
        if b == 0xF0_u8
          return false if @bytes[i + 1] < 0x90_u8
        end
        if b == 0xF4_u8
          return false if @bytes[i + 1] >= 0x90_u8
        end
        return false if b > 0xF4_u8
        i += 4
      else
        return false
      end
    end
    true
  end

  private def continuation?(b : UInt8) : Bool
    b >= 0x80_u8 && b < 0xC0_u8
  end

  # Scrub invalid UTF-8 bytes, replacing them with U+FFFD (EF BF BD).
  private def scrub_utf8(bytes : Bytes) : String
    String.build do |io|
      i = 0
      while i < bytes.size
        b = bytes[i]
        seq_len = utf8_sequence_length(b)
        if seq_len == 0 || i + seq_len > bytes.size || !valid_utf8_sequence?(bytes, i, seq_len)
          io << "\u{FFFD}"
          i += 1
        else
          seq_len.times { |j| io.write_byte(bytes[i + j]) }
          i += seq_len
        end
      end
    end
  end

  private def utf8_sequence_length(b : UInt8) : Int32
    if b < 0x80_u8;    1
    elsif b < 0xC2_u8; 0  # continuation or overlong leader
    elsif b < 0xE0_u8; 2
    elsif b < 0xF0_u8; 3
    elsif b <= 0xF4_u8; 4
    else;               0
    end
  end

  private def valid_utf8_sequence?(bytes : Bytes, start : Int32, len : Int32) : Bool
    b = bytes[start]
    case len
    when 1
      b < 0x80_u8
    when 2
      continuation?(bytes[start + 1]) && b >= 0xC2_u8
    when 3
      c1 = bytes[start + 1]
      continuation?(c1) && continuation?(bytes[start + 2]) &&
        !(b == 0xE0_u8 && c1 < 0xA0_u8) &&  # overlong
        !(b == 0xED_u8 && c1 >= 0xA0_u8)     # surrogates
    when 4
      c1 = bytes[start + 1]
      continuation?(c1) && continuation?(bytes[start + 2]) && continuation?(bytes[start + 3]) &&
        !(b == 0xF0_u8 && c1 < 0x90_u8) &&   # overlong
        !(b == 0xF4_u8 && c1 >= 0x90_u8)     # > U+10FFFF
    else
      false
    end
  end

  # -------------------------------------------------------------------------
  # RubyObject override
  # -------------------------------------------------------------------------

  def hash : UInt64
    @bytes.hash
  end
end
