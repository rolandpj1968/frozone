# RubySymbol — Crystal implementation of Ruby symbol semantics.
#
# Ruby symbols are interned, immutable, encoding-aware identifiers. The same
# name+encoding pair always returns the same object (identity equality).
#
# NOTE: The intern table is a class variable and is NOT thread-safe. Thread
# safety (e.g., a Mutex around intern-table mutations) is deferred to future
# work once the broader concurrency model is decided.

require "./ruby_string"  # pulls in RubyEncoding

# ---------------------------------------------------------------------------
# RubySymbol
# ---------------------------------------------------------------------------

class RubySymbol < RubyObject
  include Comparable(RubySymbol)

  getter name     : String
  getter encoding : RubyEncoding
  getter object_id : UInt64

  # -------------------------------------------------------------------------
  # Intern table — keyed by {name, encoding}
  # NOT thread-safe (see module doc).
  # -------------------------------------------------------------------------

  @@table   = Hash({String, RubyEncoding}, RubySymbol).new
  @@next_id = 1_u64

  # -------------------------------------------------------------------------
  # Private initializer — use .from or .from_bytes
  # -------------------------------------------------------------------------

  private def initialize(@name : String, @encoding : RubyEncoding, @object_id : UInt64)
  end

  # -------------------------------------------------------------------------
  # Factory methods
  # -------------------------------------------------------------------------

  # Return (or create) the interned RubySymbol for the given name and encoding.
  # The name is treated as a UTF-8 Crystal String; no transcoding is performed.
  def self.from(name : String, encoding : RubyEncoding = RubyEncoding::UTF_8) : RubySymbol
    key = {name, encoding}
    if sym = @@table[key]?
      sym
    else
      id = @@next_id
      @@next_id += 1
      sym = new(name, encoding, id)
      @@table[key] = sym
      sym
    end
  end

  # Return (or create) the interned RubySymbol for a raw byte slice.
  # The bytes are decoded to a Crystal String using the declared encoding;
  # for non-UTF-8 encodings, the bytes are wrapped via Latin-1 expansion
  # (best-effort) — exact transcoding is deferred.
  def self.from_bytes(bytes : Bytes, encoding : RubyEncoding) : RubySymbol
    name = case encoding
           when RubyEncoding::UTF_8, RubyEncoding::US_ASCII
             String.new(bytes)
           when RubyEncoding::ASCII_8BIT
             # Treat each byte as latin-1 / ISO-8859-1
             String.build do |io|
               bytes.each do |b|
                 if b < 0x80u8
                   io.write_byte(b)
                 else
                   io.write_byte(0xC0u8 | (b >> 6))
                   io.write_byte(0x80u8 | (b & 0x3Fu8))
                 end
               end
             end
           else
             String.new(bytes)
           end
    from(name, encoding)
  end

  # -------------------------------------------------------------------------
  # Core operations
  # -------------------------------------------------------------------------

  # Returns just the symbol name, without any colon prefix.
  def to_s : String
    @name
  end

  # Returns the Ruby inspect form: ":name" if the name is a bare identifier,
  # otherwise ":\"name\"" with the name double-quoted.
  #
  # Bare identifier rule: /\A[a-zA-Z_][a-zA-Z0-9_]*[?!]?\z/
  # Everything else (empty, starts with digit, contains spaces/special chars,
  # etc.) is quoted.
  def inspect : String
    if bare_identifier?(@name)
      ":#{@name}"
    else
      ":\"#{@name}\""
    end
  end

  # Identity equality — same interned object means same object_id.
  def ==(other : RubySymbol) : Bool
    @object_id == other.object_id
  end

  def ==(other : RubyObject) : Bool
    false
  end

  # Lexicographic ordering by name.
  def <=>(other : RubySymbol) : Int32
    @name <=> other.name
  end

  # Hash based on object_id (unique per interned symbol).
  def hash : UInt64
    @object_id
  end

  # Number of Unicode characters in the name.
  # Crystal String#size counts codepoints for valid UTF-8.
  def length : Int32
    @name.size
  end

  def empty? : Bool
    @name.empty?
  end

  # Return a new (interned) symbol with the name up-cased.
  # Uses the same encoding as self.
  def upcase : RubySymbol
    RubySymbol.from(@name.upcase, @encoding)
  end

  # Return a new (interned) symbol with the name down-cased.
  # Uses the same encoding as self.
  def downcase : RubySymbol
    RubySymbol.from(@name.downcase, @encoding)
  end

  # to_proc: stub — converting a symbol to a Proc requires VM integration
  # that is outside the scope of this low-level value-type layer.
  # Returns nil for now; VM layers should override / unwrap as needed.
  def to_proc : Nil
    nil
  end

  # -------------------------------------------------------------------------
  # Private helpers
  # -------------------------------------------------------------------------

  private def bare_identifier?(name : String) : Bool
    return false if name.empty?
    chars = name.chars
    first = chars[0]
    return false unless first.letter? || first == '_'
    # All middle characters must be alphanumeric or underscore
    middle = chars[1..]
    if middle.empty?
      # Single-character name is bare
      return true
    end
    # Optional trailing '?' or '!'
    last = middle.last
    has_suffix = (last == '?' || last == '!')
    body = has_suffix ? middle[0...-1] : middle
    body.all? { |c| c.alphanumeric? || c == '_' }
  end
end
