require "spec"
require "../../src/ruby_string"

describe RubyString do
  # -------------------------------------------------------------------------
  # Construction
  # -------------------------------------------------------------------------

  describe ".new(bytes, encoding)" do
    it "stores the bytes" do
      s = RubyString.new(Bytes[65_u8, 66_u8, 67_u8], RubyEncoding::ASCII_8BIT)
      s.bytesize.should eq 3
    end

    it "copies the provided bytes (no alias)" do
      buf = Bytes[0x41_u8, 0x42_u8]
      s = RubyString.new(buf, RubyEncoding::ASCII_8BIT)
      buf[0] = 0xFF_u8
      s.getbyte(0).should eq 0x41_u8
    end

    it "stores the encoding" do
      s = RubyString.new(Bytes[65_u8], RubyEncoding::US_ASCII)
      s.encoding.should eq RubyEncoding::US_ASCII
    end
  end

  describe ".new(str)" do
    it "stores UTF-8 bytes from a Crystal String" do
      s = RubyString.new("hello")
      s.bytesize.should eq 5
      s.encoding.should eq RubyEncoding::UTF_8
    end

    it "stores multi-byte UTF-8 correctly" do
      s = RubyString.new("café")
      s.bytesize.should eq 5  # é is 2 bytes
    end
  end

  describe ".new(str, encoding)" do
    it "tags with the given encoding, stores UTF-8 bytes" do
      s = RubyString.new("hello", RubyEncoding::US_ASCII)
      s.encoding.should eq RubyEncoding::US_ASCII
      s.bytesize.should eq 5
    end
  end

  describe ".new_ascii_8bit" do
    it "creates an ASCII-8BIT string" do
      s = RubyString.new_ascii_8bit(Bytes[0xFFu8, 0xFEu8])
      s.encoding.should eq RubyEncoding::ASCII_8BIT
      s.bytesize.should eq 2
    end
  end

  describe ".new_utf8" do
    it "creates a UTF-8 string from a Crystal String" do
      s = RubyString.new_utf8("hello")
      s.encoding.should eq RubyEncoding::UTF_8
      s.bytesize.should eq 5
    end
  end

  # -------------------------------------------------------------------------
  # bytesize / length / size / empty?
  # -------------------------------------------------------------------------

  describe "#bytesize" do
    it "returns 0 for empty" do
      RubyString.empty.bytesize.should eq 0
    end

    it "returns byte count (not char count) for multi-byte UTF-8" do
      s = RubyString.new("日本語")  # 9 bytes, 3 chars
      s.bytesize.should eq 9
    end

    it "equals length for ASCII" do
      s = RubyString.new("hello")
      s.bytesize.should eq s.length
    end
  end

  describe "#length / #size" do
    it "equals bytesize for ASCII-only UTF-8" do
      s = RubyString.new("hello")
      s.length.should eq 5
      s.size.should eq 5
    end

    it "equals bytesize for ASCII_8BIT" do
      s = RubyString.new_ascii_8bit(Bytes[0x41_u8, 0xFF_u8])
      s.length.should eq 2
    end

    it "raises NotImplementedError for non-ASCII multi-byte encoding" do
      s = RubyString.new(Bytes[0xE6_u8, 0x97_u8, 0xA5_u8], RubyEncoding::UTF_8)
      expect_raises(NotImplementedError) { s.length }
    end
  end

  describe "#empty?" do
    it "is true for empty string" do
      RubyString.empty.empty?.should be_true
    end

    it "is false for non-empty string" do
      RubyString.new("x").empty?.should be_false
    end
  end

  # -------------------------------------------------------------------------
  # ascii_only?
  # -------------------------------------------------------------------------

  describe "#ascii_only?" do
    it "is true for ASCII-only UTF-8 string" do
      s = RubyString.new("hello")
      s.ascii_only?.should be_true
    end

    it "is false for multi-byte UTF-8" do
      s = RubyString.new("café")
      s.ascii_only?.should be_false
    end

    it "is true for ASCII-only ASCII_8BIT string" do
      s = RubyString.new(Bytes[65_u8, 66_u8], RubyEncoding::ASCII_8BIT)
      s.ascii_only?.should be_true
    end

    it "is false for ASCII_8BIT with high bytes" do
      s = RubyString.new(Bytes[0xC3_u8, 0xA9_u8], RubyEncoding::ASCII_8BIT)
      s.ascii_only?.should be_false
    end

    it "is true for empty string" do
      RubyString.empty.ascii_only?.should be_true
    end

    it "returns cached value on second call" do
      s = RubyString.new("hello")
      s.ascii_only?.should be_true
      s.ascii_only?.should be_true  # from cache
    end

    it "is false for invalid UTF-8 even with all bytes < 128" do
      # Lone continuation byte — invalid UTF-8 but byte value < 128 is impossible;
      # 0x80 is a continuation byte. ascii_only? should return false for invalid UTF-8.
      s = RubyString.new(Bytes[0x80_u8], RubyEncoding::UTF_8)
      s.ascii_only?.should be_false
    end
  end

  # -------------------------------------------------------------------------
  # valid_encoding?
  # -------------------------------------------------------------------------

  describe "#valid_encoding?" do
    it "is always true for ASCII_8BIT" do
      s = RubyString.new(Bytes[0xFF_u8, 0xFE_u8, 0x00_u8], RubyEncoding::ASCII_8BIT)
      s.valid_encoding?.should be_true
    end

    it "is true for ASCII_8BIT with high bytes" do
      s = RubyString.new(Bytes[0x80_u8], RubyEncoding::ASCII_8BIT)
      s.valid_encoding?.should be_true
    end

    it "is true for valid UTF-8" do
      s = RubyString.new("hello, 世界")
      s.valid_encoding?.should be_true
    end

    it "is false for invalid UTF-8 (overlong)" do
      s = RubyString.new(Bytes[0xC0_u8, 0x80_u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "is false for truncated UTF-8 sequence" do
      s = RubyString.new(Bytes[0xC3_u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "is false for lone continuation byte in UTF-8" do
      s = RubyString.new(Bytes[0x80_u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "is false for surrogate half in UTF-8" do
      s = RubyString.new(Bytes[0xED_u8, 0xA0_u8, 0x80_u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "is true for US_ASCII with all bytes <= 127" do
      s = RubyString.from_string("hello", RubyEncoding::US_ASCII)
      s.valid_encoding?.should be_true
    end

    it "is false for US_ASCII with high bytes" do
      s = RubyString.new(Bytes[0x80_u8], RubyEncoding::US_ASCII)
      s.valid_encoding?.should be_false
    end

    it "returns cached value on second call" do
      s = RubyString.new("valid")
      s.valid_encoding?.should be_true
      s.valid_encoding?.should be_true  # from cache
    end
  end

  # -------------------------------------------------------------------------
  # frozen? / freeze! / dup
  # -------------------------------------------------------------------------

  describe "#frozen? / #freeze!" do
    it "is not frozen by default" do
      RubyString.new("hello").frozen?.should be_false
    end

    it "is frozen after freeze!" do
      s = RubyString.new("hello")
      s.freeze!
      s.frozen?.should be_true
    end

    it "freeze! returns self" do
      s = RubyString.new("hello")
      s.freeze!.should be(s)
    end
  end

  describe "#dup" do
    it "returns a new object" do
      s = RubyString.new("hello")
      s.dup.should_not be(s)
    end

    it "has the same content" do
      s = RubyString.new("hello")
      s.dup.to_s.should eq "hello"
    end

    it "is not frozen even if the original was" do
      s = RubyString.new("hello").freeze!
      s.dup.frozen?.should be_false
    end

    it "bytes are independent from original" do
      s = RubyString.new("hello")
      d = s.dup
      d.setbyte(0, 0x58_u8)
      s.getbyte(0).should eq 'h'.ord.to_u8
    end
  end

  # -------------------------------------------------------------------------
  # force_encoding (non-mutating)
  # -------------------------------------------------------------------------

  describe "#force_encoding" do
    it "returns a new RubyString with the new encoding" do
      s = RubyString.new("hello")
      t = s.force_encoding(RubyEncoding::ASCII_8BIT)
      t.encoding.should eq RubyEncoding::ASCII_8BIT
    end

    it "does not mutate the original" do
      s = RubyString.new("hello")
      s.force_encoding(RubyEncoding::ASCII_8BIT)
      s.encoding.should eq RubyEncoding::UTF_8
    end

    it "returns a different object" do
      s = RubyString.new("hello")
      t = s.force_encoding(RubyEncoding::ASCII_8BIT)
      t.should_not be(s)
    end

    it "preserves bytes exactly" do
      s = RubyString.new(Bytes[0xFF_u8, 0xFE_u8], RubyEncoding::UTF_8)
      t = s.force_encoding(RubyEncoding::ASCII_8BIT)
      t.getbyte(0).should eq 0xFF_u8
      t.getbyte(1).should eq 0xFE_u8
    end
  end

  # -------------------------------------------------------------------------
  # encode (stub)
  # -------------------------------------------------------------------------

  describe "#encode" do
    it "raises NotImplementedError" do
      s = RubyString.new("hello")
      expect_raises(NotImplementedError) { s.encode(RubyEncoding::ISO_8859_1) }
    end
  end

  # -------------------------------------------------------------------------
  # + (concatenation)
  # -------------------------------------------------------------------------

  describe "#+" do
    it "concatenates bytes of two ASCII strings" do
      a = RubyString.new("hello")
      b = RubyString.new(" world")
      c = a + b
      c.to_s.should eq "hello world"
    end

    it "result encoding is UTF_8 when both are UTF_8" do
      a = RubyString.new("hello")
      b = RubyString.new(" world")
      (a + b).encoding.should eq RubyEncoding::UTF_8
    end

    it "result encoding is ASCII_8BIT when both are ASCII_8BIT" do
      a = RubyString.new_ascii_8bit(Bytes[0x41_u8])
      b = RubyString.new_ascii_8bit(Bytes[0x42_u8])
      (a + b).encoding.should eq RubyEncoding::ASCII_8BIT
    end

    it "non-ASCII encoding wins when the other is ASCII-only" do
      # latin1-tagged ASCII string + UTF-8 ASCII string → UTF-8 wins
      ascii_only = RubyString.from_string("hello", RubyEncoding::ISO_8859_1)
      utf8_str   = RubyString.new(" world")
      result     = ascii_only + utf8_str
      result.encoding.should eq RubyEncoding::UTF_8
    end

    it "does not mutate the receiver" do
      a = RubyString.new("hello")
      b = RubyString.new(" world")
      a + b
      a.to_s.should eq "hello"
    end

    it "raises on incompatible encodings (non-ASCII content)" do
      # Two non-ASCII strings with different encodings → incompatible
      latin1 = RubyString.new(Bytes[0xE9_u8], RubyEncoding::ISO_8859_1)  # é in latin-1
      koi8   = RubyString.new(Bytes[0xC1_u8], RubyEncoding::KOI8_R)       # some KOI8 char
      expect_raises(Exception) { latin1 + koi8 }
    end
  end

  # -------------------------------------------------------------------------
  # * (repeat)
  # -------------------------------------------------------------------------

  describe "#*" do
    it "repeats the bytes n times" do
      s = RubyString.new("ab")
      r = s * 3
      r.to_s.should eq "ababab"
    end

    it "preserves encoding" do
      s = RubyString.from_string("x", RubyEncoding::US_ASCII)
      (s * 2).encoding.should eq RubyEncoding::US_ASCII
    end

    it "returns empty string for n=0" do
      s = RubyString.new("hello")
      r = s * 0
      r.bytesize.should eq 0
    end

    it "returns empty string for negative n" do
      s = RubyString.new("hello")
      r = s * (-1)
      r.bytesize.should eq 0
    end
  end

  # -------------------------------------------------------------------------
  # == (eql? semantics — same bytes + same encoding)
  # -------------------------------------------------------------------------

  describe "#==" do
    it "is true for same bytes and same encoding" do
      a = RubyString.new("hello")
      b = RubyString.new("hello")
      (a == b).should be_true
    end

    it "is false for different bytes" do
      a = RubyString.new("hello")
      b = RubyString.new("world")
      (a == b).should be_false
    end

    it "is false for same bytes but different encoding" do
      a = RubyString.from_string("hello", RubyEncoding::UTF_8)
      b = RubyString.from_string("hello", RubyEncoding::US_ASCII)
      (a == b).should be_false
    end
  end

  # -------------------------------------------------------------------------
  # ruby_eql? (MRI == semantics — ASCII-only strings match across encodings)
  # -------------------------------------------------------------------------

  describe "#ruby_eql?" do
    it "is true for identical ASCII strings with different encodings" do
      a = RubyString.from_string("hello", RubyEncoding::UTF_8)
      b = RubyString.from_string("hello", RubyEncoding::US_ASCII)
      a.ruby_eql?(b).should be_true
    end

    it "is false for non-ASCII strings with different encodings" do
      # Bytes are the same but encodings differ and content is not ASCII-only
      a = RubyString.new(Bytes[0xE9_u8], RubyEncoding::ISO_8859_1)
      b = RubyString.new(Bytes[0xE9_u8], RubyEncoding::UTF_8)
      a.ruby_eql?(b).should be_false
    end

    it "is false for different bytes" do
      a = RubyString.new("hello")
      b = RubyString.new("world")
      a.ruby_eql?(b).should be_false
    end
  end

  # -------------------------------------------------------------------------
  # getbyte / setbyte
  # -------------------------------------------------------------------------

  describe "#getbyte" do
    it "returns the byte at the given index" do
      s = RubyString.new("ABC")
      s.getbyte(0).should eq 0x41_u8
      s.getbyte(2).should eq 0x43_u8
    end

    it "returns nil for out-of-range index" do
      s = RubyString.new("ABC")
      s.getbyte(3).should be_nil
    end

    it "supports negative indices" do
      s = RubyString.new("ABC")
      s.getbyte(-1).should eq 0x43_u8
    end

    it "returns nil for negative index out of range" do
      s = RubyString.new("ABC")
      s.getbyte(-4).should be_nil
    end
  end

  describe "#setbyte" do
    it "modifies the byte at the given index" do
      s = RubyString.new("ABC")
      s.setbyte(0, 0x61_u8)
      s.getbyte(0).should eq 0x61_u8
    end

    it "returns the written byte value" do
      s = RubyString.new("ABC")
      s.setbyte(1, 0x78_u8).should eq 0x78_u8
    end

    it "clears encoding caches after mutation" do
      s = RubyString.new("ABC")
      s.ascii_only?.should be_true
      s.setbyte(0, 0xC3_u8)
      s.ascii_only?.should be_false
    end

    it "raises RubyFrozenError on frozen string" do
      s = RubyString.new("hello").freeze!
      expect_raises(RubyFrozenError) { s.setbyte(0, 0x41_u8) }
    end

    it "raises IndexError for out-of-range" do
      s = RubyString.new("ABC")
      expect_raises(IndexError) { s.setbyte(10, 0x41_u8) }
    end
  end

  # -------------------------------------------------------------------------
  # inspect
  # -------------------------------------------------------------------------

  describe "#inspect" do
    it "double-quotes an ASCII string" do
      s = RubyString.new("hello")
      s.inspect.should eq "\"hello\""
    end

    it "escapes backslash" do
      s = RubyString.new("a\\b")
      s.inspect.should eq "\"a\\\\b\""
    end

    it "escapes double-quote" do
      s = RubyString.new("say \"hi\"")
      s.inspect.should eq "\"say \\\"hi\\\"\""
    end

    it "escapes newline as \\n" do
      s = RubyString.new("a\nb")
      s.inspect.should eq "\"a\\nb\""
    end

    it "escapes tab as \\t" do
      s = RubyString.new("a\tb")
      s.inspect.should eq "\"a\\tb\""
    end

    it "hex-escapes non-ASCII bytes" do
      s = RubyString.new(Bytes[0xE9_u8], RubyEncoding::ASCII_8BIT)
      s.inspect.should eq "\"\\xE9\""
    end

    it "hex-escapes NUL byte" do
      s = RubyString.new(Bytes[0x00_u8], RubyEncoding::ASCII_8BIT)
      s.inspect.should eq "\"\\x00\""
    end

    it "handles empty string" do
      s = RubyString.empty
      s.inspect.should eq "\"\""
    end
  end

  # -------------------------------------------------------------------------
  # to_s
  # -------------------------------------------------------------------------

  describe "#to_s" do
    it "returns the crystal string for ASCII content" do
      s = RubyString.new("hello")
      s.to_s.should eq "hello"
    end

    it "replaces invalid UTF-8 with U+FFFD" do
      s = RubyString.new(Bytes[0x41_u8, 0xFF_u8, 0x42_u8], RubyEncoding::UTF_8)
      result = s.to_s
      result.should contain("A")
      result.should contain("B")
      result.should contain("\u{FFFD}")
    end
  end
end
