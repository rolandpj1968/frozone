require "spec"
require "../src/ruby_symbol"

describe RubySymbol do
  # -----------------------------------------------------------------------
  # Interning
  # -----------------------------------------------------------------------

  describe ".from interning" do
    it "returns the same object for the same name (UTF_8 default)" do
      a = RubySymbol.from("foo")
      b = RubySymbol.from("foo")
      a.same?(b).should be_true
    end

    it "returns the same object when encoding is specified explicitly" do
      a = RubySymbol.from("bar", RubyEncoding::UTF_8)
      b = RubySymbol.from("bar", RubyEncoding::UTF_8)
      a.same?(b).should be_true
    end

    it "returns different objects for different names" do
      a = RubySymbol.from("foo")
      b = RubySymbol.from("baz")
      a.same?(b).should be_false
    end

    it "returns different objects for same name with different encodings" do
      a = RubySymbol.from("foo", RubyEncoding::UTF_8)
      b = RubySymbol.from("foo", RubyEncoding::ASCII_8BIT)
      a.same?(b).should be_false
    end

    it "assigns monotonically increasing object_ids" do
      # Use unique names to ensure fresh interning
      x = RubySymbol.from("__spec_id_x__")
      y = RubySymbol.from("__spec_id_y__")
      y.object_id.should be > x.object_id
    end
  end

  describe ".from_bytes" do
    it "interns a symbol from raw UTF-8 bytes" do
      bytes = "hello".to_slice
      sym = RubySymbol.from_bytes(bytes, RubyEncoding::UTF_8)
      sym.name.should eq "hello"
      sym.encoding.should eq RubyEncoding::UTF_8
    end

    it "returns the same object as .from for equivalent name" do
      bytes = "world".to_slice
      a = RubySymbol.from_bytes(bytes, RubyEncoding::UTF_8)
      b = RubySymbol.from("world", RubyEncoding::UTF_8)
      a.same?(b).should be_true
    end

    it "handles ASCII_8BIT encoding" do
      bytes = Bytes[0x68u8, 0x69u8]  # "hi"
      sym = RubySymbol.from_bytes(bytes, RubyEncoding::ASCII_8BIT)
      sym.encoding.should eq RubyEncoding::ASCII_8BIT
    end
  end

  # -----------------------------------------------------------------------
  # Accessors
  # -----------------------------------------------------------------------

  describe "#name and #encoding" do
    it "exposes the name" do
      sym = RubySymbol.from("my_symbol")
      sym.name.should eq "my_symbol"
    end

    it "exposes the encoding" do
      sym = RubySymbol.from("my_symbol", RubyEncoding::US_ASCII)
      sym.encoding.should eq RubyEncoding::US_ASCII
    end
  end

  # -----------------------------------------------------------------------
  # to_s / inspect
  # -----------------------------------------------------------------------

  describe "#to_s" do
    it "returns the bare name without a colon" do
      sym = RubySymbol.from("hello")
      sym.to_s.should eq "hello"
    end

    it "returns empty string for the empty symbol" do
      sym = RubySymbol.from("")
      sym.to_s.should eq ""
    end
  end

  describe "#inspect" do
    it "returns :name for simple identifiers" do
      sym = RubySymbol.from("foo")
      sym.inspect.should eq ":foo"
    end

    it "returns :name for identifiers with underscore" do
      sym = RubySymbol.from("my_var")
      sym.inspect.should eq ":my_var"
    end

    it "returns :name for identifiers ending with ?" do
      sym = RubySymbol.from("valid?")
      sym.inspect.should eq ":valid?"
    end

    it "returns :name for identifiers ending with !" do
      sym = RubySymbol.from("save!")
      sym.inspect.should eq ":save!"
    end

    it "quotes names with spaces" do
      sym = RubySymbol.from("hello world")
      sym.inspect.should eq ":\"hello world\""
    end

    it "quotes names starting with a digit" do
      sym = RubySymbol.from("1abc")
      sym.inspect.should eq ":\"1abc\""
    end

    it "quotes empty name" do
      sym = RubySymbol.from("")
      sym.inspect.should eq ":\"\""
    end

    it "quotes names with special characters" do
      sym = RubySymbol.from("foo-bar")
      sym.inspect.should eq ":\"foo-bar\""
    end

    it "returns :name for single-letter identifier" do
      sym = RubySymbol.from("x")
      sym.inspect.should eq ":x"
    end

    it "returns :name for identifier starting with underscore" do
      sym = RubySymbol.from("_private")
      sym.inspect.should eq ":_private"
    end
  end

  # -----------------------------------------------------------------------
  # Equality
  # -----------------------------------------------------------------------

  describe "#==" do
    it "is true for the same interned symbol" do
      a = RubySymbol.from("foo")
      b = RubySymbol.from("foo")
      (a == b).should be_true
    end

    it "is false for different symbols" do
      a = RubySymbol.from("foo")
      b = RubySymbol.from("bar")
      (a == b).should be_false
    end

    it "is false for same name with different encodings" do
      a = RubySymbol.from("foo", RubyEncoding::UTF_8)
      b = RubySymbol.from("foo", RubyEncoding::ASCII_8BIT)
      (a == b).should be_false
    end
  end

  # -----------------------------------------------------------------------
  # Ordering
  # -----------------------------------------------------------------------

  describe "#<=>" do
    it "returns 0 for equal symbols" do
      a = RubySymbol.from("apple")
      b = RubySymbol.from("apple")
      (a <=> b).should eq 0
    end

    it "returns negative when self comes before other lexicographically" do
      a = RubySymbol.from("apple")
      b = RubySymbol.from("banana")
      (a <=> b).should be < 0
    end

    it "returns positive when self comes after other lexicographically" do
      a = RubySymbol.from("zebra")
      b = RubySymbol.from("ant")
      (a <=> b).should be > 0
    end

    it "sorts an array of symbols correctly" do
      syms = [
        RubySymbol.from("zebra"),
        RubySymbol.from("ant"),
        RubySymbol.from("mango"),
      ]
      sorted = syms.sort
      sorted.map(&.name).should eq ["ant", "mango", "zebra"]
    end
  end

  # -----------------------------------------------------------------------
  # hash
  # -----------------------------------------------------------------------

  describe "#hash" do
    it "returns the same hash for the same symbol" do
      a = RubySymbol.from("foo")
      b = RubySymbol.from("foo")
      a.hash.should eq b.hash
    end

    it "returns different hashes for different symbols (high probability)" do
      a = RubySymbol.from("foo")
      b = RubySymbol.from("bar")
      a.hash.should_not eq b.hash
    end
  end

  # -----------------------------------------------------------------------
  # length / empty?
  # -----------------------------------------------------------------------

  describe "#length" do
    it "returns the character count of the name" do
      sym = RubySymbol.from("hello")
      sym.length.should eq 5
    end

    it "returns 0 for an empty name" do
      sym = RubySymbol.from("")
      sym.length.should eq 0
    end
  end

  describe "#empty?" do
    it "is true for an empty name" do
      sym = RubySymbol.from("")
      sym.empty?.should be_true
    end

    it "is false for a non-empty name" do
      sym = RubySymbol.from("x")
      sym.empty?.should be_false
    end
  end

  # -----------------------------------------------------------------------
  # upcase / downcase
  # -----------------------------------------------------------------------

  describe "#upcase" do
    it "returns a new interned symbol with the name up-cased" do
      sym = RubySymbol.from("hello")
      up = sym.upcase
      up.name.should eq "HELLO"
    end

    it "the result is properly interned" do
      a = RubySymbol.from("hello").upcase
      b = RubySymbol.from("HELLO")
      a.same?(b).should be_true
    end

    it "preserves encoding" do
      sym = RubySymbol.from("hello", RubyEncoding::US_ASCII)
      up = sym.upcase
      up.encoding.should eq RubyEncoding::US_ASCII
    end
  end

  describe "#downcase" do
    it "returns a new interned symbol with the name down-cased" do
      sym = RubySymbol.from("WORLD")
      dn = sym.downcase
      dn.name.should eq "world"
    end

    it "the result is properly interned" do
      a = RubySymbol.from("WORLD").downcase
      b = RubySymbol.from("world")
      a.same?(b).should be_true
    end

    it "preserves encoding" do
      sym = RubySymbol.from("WORLD", RubyEncoding::US_ASCII)
      dn = sym.downcase
      dn.encoding.should eq RubyEncoding::US_ASCII
    end
  end

  # -----------------------------------------------------------------------
  # to_proc
  # -----------------------------------------------------------------------

  describe "#to_proc" do
    it "returns nil (stub)" do
      sym = RubySymbol.from("foo")
      sym.to_proc.should be_nil
    end
  end
end
