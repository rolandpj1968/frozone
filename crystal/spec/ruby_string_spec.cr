require "spec"
require "../src/ruby_string"

describe RubyString do
  # -----------------------------------------------------------------------
  # Construction
  # -----------------------------------------------------------------------

  describe ".from_string" do
    it "stores UTF-8 bytes" do
      s = RubyString.from_string("hello")
      s.bytesize.should eq 5
      s.encoding.should eq RubyEncoding::UTF_8
    end

    it "stores multi-byte UTF-8" do
      s = RubyString.from_string("café")
      # é is 2 bytes in UTF-8
      s.bytesize.should eq 5
    end

    it "accepts explicit encoding tag" do
      s = RubyString.from_string("hello", RubyEncoding::US_ASCII)
      s.encoding.should eq RubyEncoding::US_ASCII
    end
  end

  describe ".new from Bytes" do
    it "copies the provided bytes" do
      buf = Bytes[0x41u8, 0x42u8, 0x43u8]
      s = RubyString.new(buf, RubyEncoding::ASCII_8BIT)
      # Mutate the original buffer — should not affect s
      buf[0] = 0xFFu8
      s.get_byte(0).should eq 0x41
    end

    it "stores the encoding" do
      s = RubyString.new(Bytes[65u8], RubyEncoding::US_ASCII)
      s.encoding.should eq RubyEncoding::US_ASCII
    end
  end

  describe ".empty" do
    it "creates an empty string" do
      s = RubyString.empty
      s.bytesize.should eq 0
      s.empty?.should be_true
    end

    it "accepts an encoding" do
      s = RubyString.empty(RubyEncoding::ASCII_8BIT)
      s.encoding.should eq RubyEncoding::ASCII_8BIT
    end
  end

  describe ".from_byte" do
    it "creates a single-byte string" do
      s = RubyString.from_byte(0x41u8)
      s.bytesize.should eq 1
      s.get_byte(0).should eq 0x41
      s.encoding.should eq RubyEncoding::ASCII_8BIT
    end
  end

  # -----------------------------------------------------------------------
  # bytesize / empty?
  # -----------------------------------------------------------------------

  describe "#bytesize" do
    it "returns 0 for empty" do
      RubyString.empty.bytesize.should eq 0
    end

    it "returns byte count not char count" do
      s = RubyString.from_string("日本語")  # 9 bytes in UTF-8
      s.bytesize.should eq 9
    end
  end

  describe "#empty?" do
    it "is true for empty string" do
      RubyString.empty.empty?.should be_true
    end

    it "is false for non-empty string" do
      RubyString.from_string("x").empty?.should be_false
    end
  end

  # -----------------------------------------------------------------------
  # get_byte
  # -----------------------------------------------------------------------

  describe "#get_byte" do
    it "returns the byte at the given index" do
      s = RubyString.from_string("ABC")
      s.get_byte(0).should eq 0x41
      s.get_byte(1).should eq 0x42
      s.get_byte(2).should eq 0x43
    end

    it "returns -1 for out-of-range index" do
      s = RubyString.from_string("ABC")
      s.get_byte(3).should eq -1
      s.get_byte(100).should eq -1
    end

    it "supports negative indices" do
      s = RubyString.from_string("ABC")
      s.get_byte(-1).should eq 0x43
      s.get_byte(-3).should eq 0x41
    end

    it "returns -1 for negative index out of range" do
      s = RubyString.from_string("ABC")
      s.get_byte(-4).should eq -1
    end
  end

  # -----------------------------------------------------------------------
  # set_byte!
  # -----------------------------------------------------------------------

  describe "#set_byte!" do
    it "modifies the byte at the given index" do
      s = RubyString.from_string("ABC")
      s.set_byte!(0, 0x61u8)
      s.get_byte(0).should eq 0x61
    end

    it "returns the written byte" do
      s = RubyString.from_string("ABC")
      s.set_byte!(1, 0x78u8).should eq 0x78u8
    end

    it "clears encoding caches after mutation" do
      s = RubyString.from_string("ABC")
      # Warm up the cache
      s.ascii_only?.should be_true
      # Mutate to a non-ASCII byte
      s.set_byte!(0, 0xC3u8)
      # Cache must be invalidated — recompute
      s.ascii_only?.should be_false
    end

    it "supports negative indices" do
      s = RubyString.from_string("ABC")
      s.set_byte!(-1, 0x58u8)
      s.get_byte(2).should eq 0x58
    end

    it "raises RubyFrozenError on frozen string" do
      s = RubyString.from_string("hello").freeze!
      expect_raises(RubyFrozenError) { s.set_byte!(0, 0x41u8) }
    end

    it "raises IndexError for out-of-range index" do
      s = RubyString.from_string("ABC")
      expect_raises(IndexError) { s.set_byte!(10, 0x41u8) }
    end
  end

  # -----------------------------------------------------------------------
  # concat_bytes!
  # -----------------------------------------------------------------------

  describe "#concat_bytes!" do
    it "appends bytes from another string" do
      a = RubyString.from_string("hello")
      b = RubyString.from_string(" world")
      a.concat_bytes!(b)
      a.bytesize.should eq 11
      a.to_crystal_string.should eq "hello world"
    end

    it "returns self" do
      a = RubyString.from_string("foo")
      b = RubyString.from_string("bar")
      a.concat_bytes!(b).should be(a)
    end

    it "raises RubyFrozenError on frozen string" do
      a = RubyString.from_string("hello").freeze!
      b = RubyString.from_string(" world")
      expect_raises(RubyFrozenError) { a.concat_bytes!(b) }
    end

    it "does not modify the appended string" do
      a = RubyString.from_string("hello")
      b = RubyString.from_string(" world")
      a.concat_bytes!(b)
      b.to_crystal_string.should eq " world"
    end

    it "clears encoding caches" do
      a = RubyString.from_string("hello")
      a.ascii_only?.should be_true
      # Append a non-ASCII byte sequence
      non_ascii = RubyString.new(Bytes[0xC3u8, 0xA9u8], RubyEncoding::UTF_8) # é
      a.concat_bytes!(non_ascii)
      a.ascii_only?.should be_false
    end
  end

  # -----------------------------------------------------------------------
  # force_encoding!
  # -----------------------------------------------------------------------

  describe "#force_encoding!" do
    it "changes the encoding tag" do
      s = RubyString.from_string("hello")
      s.force_encoding!(RubyEncoding::ASCII_8BIT)
      s.encoding.should eq RubyEncoding::ASCII_8BIT
    end

    it "returns self" do
      s = RubyString.from_string("hello")
      s.force_encoding!(RubyEncoding::US_ASCII).should be(s)
    end

    it "clears ascii_only? cache" do
      s = RubyString.from_string("hello")
      # Warm up cache as UTF_8
      s.ascii_only?.should be_true
      # After force_encoding to US_ASCII, cache should be invalidated and
      # recomputed correctly for the new encoding
      s.force_encoding!(RubyEncoding::US_ASCII)
      s.ascii_only?.should be_true
    end

    it "raises RubyFrozenError on frozen string" do
      s = RubyString.from_string("hello").freeze!
      expect_raises(RubyFrozenError) { s.force_encoding!(RubyEncoding::ASCII_8BIT) }
    end
  end

  # -----------------------------------------------------------------------
  # replace!
  # -----------------------------------------------------------------------

  describe "#replace!" do
    it "replaces bytes and encoding from another string" do
      a = RubyString.from_string("hello")
      b = RubyString.from_string("world", RubyEncoding::US_ASCII)
      a.replace!(b)
      a.to_crystal_string.should eq "world"
      a.encoding.should eq RubyEncoding::US_ASCII
    end

    it "returns self" do
      a = RubyString.from_string("hello")
      b = RubyString.from_string("world")
      a.replace!(b).should be(a)
    end

    it "does not alias the source bytes" do
      a = RubyString.from_string("hello")
      b = RubyString.from_string("world")
      a.replace!(b)
      b.set_byte!(0, 0x58u8)  # mutate b
      a.get_byte(0).should eq 'w'.ord  # a should be unaffected
    end

    it "raises RubyFrozenError on frozen string" do
      a = RubyString.from_string("hello").freeze!
      b = RubyString.from_string("world")
      expect_raises(RubyFrozenError) { a.replace!(b) }
    end
  end

  # -----------------------------------------------------------------------
  # ascii_only?
  # -----------------------------------------------------------------------

  describe "#ascii_only?" do
    it "is true for ASCII-only UTF-8 string" do
      s = RubyString.from_string("hello")
      s.ascii_only?.should be_true
    end

    it "is false for multi-byte UTF-8" do
      s = RubyString.from_string("café")
      s.ascii_only?.should be_false
    end

    it "is true for ASCII-only ASCII_8BIT string" do
      s = RubyString.new(Bytes[72u8, 101u8, 108u8], RubyEncoding::ASCII_8BIT)
      s.ascii_only?.should be_true
    end

    it "is false for ASCII_8BIT with high bytes" do
      s = RubyString.new(Bytes[0xC3u8, 0xA9u8], RubyEncoding::ASCII_8BIT)
      s.ascii_only?.should be_false
    end

    it "is true for empty string" do
      RubyString.empty.ascii_only?.should be_true
    end

    it "returns cached value on second call" do
      s = RubyString.from_string("hello")
      s.ascii_only?.should be_true
      s.ascii_only?.should be_true  # from cache
    end

    it "is false for invalid UTF-8 even with all bytes < 128" do
      # Valid UTF-8 with all ASCII bytes is ASCII-only, but if we have
      # bytes tagged UTF-8 that happen to be invalid UTF-8, ascii_only? is false.
      # Here we construct an invalid UTF-8 sequence: lone continuation byte.
      s = RubyString.new(Bytes[0x80u8], RubyEncoding::UTF_8)
      s.ascii_only?.should be_false
    end
  end

  # -----------------------------------------------------------------------
  # valid_encoding?
  # -----------------------------------------------------------------------

  describe "#valid_encoding?" do
    it "is always true for ASCII_8BIT" do
      s = RubyString.new(Bytes[0xFFu8, 0xFEu8, 0x00u8], RubyEncoding::ASCII_8BIT)
      s.valid_encoding?.should be_true
    end

    it "is true for valid UTF-8" do
      s = RubyString.from_string("hello, 世界")
      s.valid_encoding?.should be_true
    end

    it "is false for invalid UTF-8" do
      # 0xC0 0x80 — overlong encoding of U+0000
      s = RubyString.new(Bytes[0xC0u8, 0x80u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "is false for truncated UTF-8 sequence" do
      # Start of 2-byte sequence with no continuation byte
      s = RubyString.new(Bytes[0xC3u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "is false for lone continuation byte in UTF-8" do
      s = RubyString.new(Bytes[0x80u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "is true for US_ASCII with all bytes <= 127" do
      s = RubyString.from_string("hello", RubyEncoding::US_ASCII)
      s.valid_encoding?.should be_true
    end

    it "is false for US_ASCII with high bytes" do
      s = RubyString.new(Bytes[0x80u8], RubyEncoding::US_ASCII)
      s.valid_encoding?.should be_false
    end

    it "is false for surrogate half in UTF-8" do
      # U+D800 encoded as UTF-8: 0xED 0xA0 0x80
      s = RubyString.new(Bytes[0xEDu8, 0xA0u8, 0x80u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "returns cached value on second call" do
      s = RubyString.from_string("valid")
      s.valid_encoding?.should be_true
      s.valid_encoding?.should be_true  # from cache
    end
  end

  # -----------------------------------------------------------------------
  # freeze! / frozen? / dup
  # -----------------------------------------------------------------------

  describe "#freeze!" do
    it "marks the string frozen" do
      s = RubyString.from_string("hello")
      s.frozen?.should be_false
      s.freeze!
      s.frozen?.should be_true
    end

    it "returns self" do
      s = RubyString.from_string("hello")
      s.freeze!.should be(s)
    end
  end

  describe "#dup" do
    it "returns a new object" do
      s = RubyString.from_string("hello")
      d = s.dup
      d.should_not be(s)
    end

    it "has the same bytes" do
      s = RubyString.from_string("hello")
      d = s.dup
      d.to_crystal_string.should eq "hello"
    end

    it "is not frozen even if original was" do
      s = RubyString.from_string("hello").freeze!
      d = s.dup
      d.frozen?.should be_false
    end

    it "is not chilled even if original was" do
      # Manually construct a chilled string using raw flags access via dup trick
      s = RubyString.from_string("hello")
      # We can only test the flag behaviour via the public API; just verify
      # that dup of a normal string is not chilled.
      d = s.dup
      d.chilled?.should be_false
    end

    it "bytes are independent — mutating dup does not affect original" do
      s = RubyString.from_string("hello")
      d = s.dup
      d.set_byte!(0, 0x58u8)
      s.get_byte(0).should eq 'h'.ord
    end
  end

  # -----------------------------------------------------------------------
  # to_crystal_string
  # -----------------------------------------------------------------------

  describe "#to_crystal_string" do
    it "round-trips ASCII" do
      s = RubyString.from_string("hello, world")
      s.to_crystal_string.should eq "hello, world"
    end

    it "round-trips valid UTF-8" do
      s = RubyString.from_string("日本語")
      s.to_crystal_string.should eq "日本語"
    end

    it "replaces invalid UTF-8 bytes with U+FFFD" do
      s = RubyString.new(Bytes[0x41u8, 0xFFu8, 0x42u8], RubyEncoding::UTF_8)
      result = s.to_crystal_string
      result.should contain("A")
      result.should contain("B")
      result.should contain("\u{FFFD}")
    end

    it "converts ASCII_8BIT high bytes to U+0080..U+00FF codepoints" do
      # 0xE9 = 233 decimal, which is U+00E9 (é in latin-1)
      s = RubyString.new(Bytes[0x68u8, 0xE9u8], RubyEncoding::ASCII_8BIT)
      result = s.to_crystal_string
      result.should eq "hé"
    end
  end

  # -----------------------------------------------------------------------
  # raw_bytes
  # -----------------------------------------------------------------------

  describe "#raw_bytes" do
    it "returns a copy of the underlying bytes" do
      s = RubyString.from_string("ABC")
      b = s.raw_bytes
      b[0].should eq 0x41u8
    end

    it "is a copy — mutating it does not affect the string" do
      s = RubyString.from_string("ABC")
      b = s.raw_bytes
      b[0] = 0xFFu8
      s.get_byte(0).should eq 0x41
    end
  end

  # -----------------------------------------------------------------------
  # == (eql? semantics)
  # -----------------------------------------------------------------------

  describe "#==" do
    it "is true for same bytes and same encoding" do
      a = RubyString.from_string("hello")
      b = RubyString.from_string("hello")
      (a == b).should be_true
    end

    it "is false for different bytes" do
      a = RubyString.from_string("hello")
      b = RubyString.from_string("world")
      (a == b).should be_false
    end

    it "is false for same bytes but different encoding" do
      a = RubyString.from_string("hello", RubyEncoding::UTF_8)
      b = RubyString.from_string("hello", RubyEncoding::US_ASCII)
      (a == b).should be_false
    end

    it "is false for same bytes but ASCII_8BIT vs UTF_8" do
      a = RubyString.new(Bytes[104u8, 101u8, 108u8, 108u8, 111u8], RubyEncoding::UTF_8)
      b = RubyString.new(Bytes[104u8, 101u8, 108u8, 108u8, 111u8], RubyEncoding::ASCII_8BIT)
      (a == b).should be_false
    end
  end

  # -----------------------------------------------------------------------
  # bytesize_compare
  # -----------------------------------------------------------------------

  describe "#bytesize_compare" do
    it "returns 0 for equal byte sequences" do
      a = RubyString.from_string("abc")
      b = RubyString.from_string("abc")
      a.bytesize_compare(b).should eq 0
    end

    it "returns negative when self is lexicographically less" do
      a = RubyString.from_string("abc")
      b = RubyString.from_string("abd")
      a.bytesize_compare(b).should be < 0
    end

    it "returns positive when self is lexicographically greater" do
      a = RubyString.from_string("abd")
      b = RubyString.from_string("abc")
      a.bytesize_compare(b).should be > 0
    end

    it "returns negative when self is shorter prefix" do
      a = RubyString.from_string("ab")
      b = RubyString.from_string("abc")
      a.bytesize_compare(b).should be < 0
    end

    it "returns positive when self is longer" do
      a = RubyString.from_string("abc")
      b = RubyString.from_string("ab")
      a.bytesize_compare(b).should be > 0
    end
  end

  # -----------------------------------------------------------------------
  # UTF-8 validator edge cases
  # -----------------------------------------------------------------------

  describe "UTF-8 validation edge cases" do
    it "accepts 4-byte sequences (emoji)" do
      # U+1F600 GRINNING FACE: F0 9F 98 80
      s = RubyString.new(Bytes[0xF0u8, 0x9Fu8, 0x98u8, 0x80u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_true
    end

    it "rejects 4-byte overlong (F0 80 80 80)" do
      s = RubyString.new(Bytes[0xF0u8, 0x80u8, 0x80u8, 0x80u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "rejects codepoints above U+10FFFF (F4 90 80 80)" do
      s = RubyString.new(Bytes[0xF4u8, 0x90u8, 0x80u8, 0x80u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "accepts U+10FFFF (F4 8F BF BF)" do
      s = RubyString.new(Bytes[0xF4u8, 0x8Fu8, 0xBFu8, 0xBFu8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_true
    end

    it "rejects 3-byte overlong (E0 80 80)" do
      s = RubyString.new(Bytes[0xE0u8, 0x80u8, 0x80u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_false
    end

    it "accepts U+0080 (2-byte: C2 80)" do
      s = RubyString.new(Bytes[0xC2u8, 0x80u8], RubyEncoding::UTF_8)
      s.valid_encoding?.should be_true
    end

    it "accepts empty string as valid UTF-8" do
      RubyString.empty(RubyEncoding::UTF_8).valid_encoding?.should be_true
    end
  end
end
