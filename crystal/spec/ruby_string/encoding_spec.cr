require "spec"
require "../../src/ruby_string/encoding"

describe RubyEncoding do
  # -------------------------------------------------------------------------
  # .from_name — canonical names
  # -------------------------------------------------------------------------

  describe ".from_name" do
    it "recognises UTF-8 by exact name" do
      RubyEncoding.from_name("UTF-8").should eq RubyEncoding::UTF_8
    end

    it "recognises utf-8 case-insensitively" do
      RubyEncoding.from_name("utf-8").should eq RubyEncoding::UTF_8
    end

    it "recognises utf8 (no hyphen)" do
      RubyEncoding.from_name("utf8").should eq RubyEncoding::UTF_8
    end

    it "recognises UTF8 (no hyphen, upper)" do
      RubyEncoding.from_name("UTF8").should eq RubyEncoding::UTF_8
    end

    it "recognises ASCII-8BIT by exact name" do
      RubyEncoding.from_name("ASCII-8BIT").should eq RubyEncoding::ASCII_8BIT
    end

    it "recognises BINARY as alias for ASCII-8BIT" do
      RubyEncoding.from_name("binary").should eq RubyEncoding::ASCII_8BIT
    end

    it "recognises BINARY upper-case" do
      RubyEncoding.from_name("BINARY").should eq RubyEncoding::ASCII_8BIT
    end

    it "recognises US-ASCII by canonical name" do
      RubyEncoding.from_name("US-ASCII").should eq RubyEncoding::US_ASCII
    end

    it "recognises ASCII as alias for US-ASCII" do
      RubyEncoding.from_name("ascii").should eq RubyEncoding::US_ASCII
    end

    it "recognises ASCII upper-case" do
      RubyEncoding.from_name("ASCII").should eq RubyEncoding::US_ASCII
    end

    it "recognises UTF-16LE" do
      RubyEncoding.from_name("UTF-16LE").should eq RubyEncoding::UTF_16LE
    end

    it "recognises UTF-16BE" do
      RubyEncoding.from_name("UTF-16BE").should eq RubyEncoding::UTF_16BE
    end

    it "recognises UTF-32LE" do
      RubyEncoding.from_name("UTF-32LE").should eq RubyEncoding::UTF_32LE
    end

    it "recognises UTF-32BE" do
      RubyEncoding.from_name("UTF-32BE").should eq RubyEncoding::UTF_32BE
    end

    it "recognises ISO-8859-1" do
      RubyEncoding.from_name("ISO-8859-1").should eq RubyEncoding::ISO_8859_1
    end

    it "recognises latin1 as alias for ISO-8859-1" do
      RubyEncoding.from_name("latin1").should eq RubyEncoding::ISO_8859_1
    end

    it "recognises ISO-8859-15" do
      RubyEncoding.from_name("ISO-8859-15").should eq RubyEncoding::ISO_8859_15
    end

    it "recognises Windows-1252" do
      RubyEncoding.from_name("Windows-1252").should eq RubyEncoding::WINDOWS_1252
    end

    it "recognises CP1252 as alias for Windows-1252" do
      RubyEncoding.from_name("CP1252").should eq RubyEncoding::WINDOWS_1252
    end

    it "recognises KOI8-R" do
      RubyEncoding.from_name("KOI8-R").should eq RubyEncoding::KOI8_R
    end

    it "recognises KOI8-U" do
      RubyEncoding.from_name("KOI8-U").should eq RubyEncoding::KOI8_U
    end

    it "recognises Shift_JIS" do
      RubyEncoding.from_name("Shift_JIS").should eq RubyEncoding::SHIFT_JIS
    end

    it "recognises SJIS as alias for Shift_JIS" do
      RubyEncoding.from_name("SJIS").should eq RubyEncoding::SHIFT_JIS
    end

    it "recognises EUC-JP" do
      RubyEncoding.from_name("EUC-JP").should eq RubyEncoding::EUC_JP
    end

    it "recognises CP932 as alias for Windows-31J" do
      RubyEncoding.from_name("CP932").should eq RubyEncoding::WINDOWS_31J
    end

    it "recognises GBK" do
      RubyEncoding.from_name("GBK").should eq RubyEncoding::GBK
    end

    it "recognises Big5" do
      RubyEncoding.from_name("Big5").should eq RubyEncoding::BIG5
    end

    it "returns UNKNOWN for unrecognised name" do
      RubyEncoding.from_name("NOT-AN-ENCODING").should eq RubyEncoding::UNKNOWN
    end

    it "returns UNKNOWN for empty string" do
      RubyEncoding.from_name("").should eq RubyEncoding::UNKNOWN
    end
  end

  # -------------------------------------------------------------------------
  # .binary and .ascii convenience class methods
  # -------------------------------------------------------------------------

  describe ".binary" do
    it "returns ASCII_8BIT" do
      RubyEncoding.binary.should eq RubyEncoding::ASCII_8BIT
    end
  end

  describe ".ascii" do
    it "returns US_ASCII" do
      RubyEncoding.ascii.should eq RubyEncoding::US_ASCII
    end
  end

  # -------------------------------------------------------------------------
  # #name — canonical MRI names
  # -------------------------------------------------------------------------

  describe "#name" do
    it "UTF_8 has name UTF-8" do
      RubyEncoding::UTF_8.name.should eq "UTF-8"
    end

    it "ASCII_8BIT has name ASCII-8BIT" do
      RubyEncoding::ASCII_8BIT.name.should eq "ASCII-8BIT"
    end

    it "US_ASCII has name US-ASCII" do
      RubyEncoding::US_ASCII.name.should eq "US-ASCII"
    end

    it "UTF_16LE has name UTF-16LE" do
      RubyEncoding::UTF_16LE.name.should eq "UTF-16LE"
    end

    it "UTF_16BE has name UTF-16BE" do
      RubyEncoding::UTF_16BE.name.should eq "UTF-16BE"
    end

    it "UTF_32LE has name UTF-32LE" do
      RubyEncoding::UTF_32LE.name.should eq "UTF-32LE"
    end

    it "UTF_32BE has name UTF-32BE" do
      RubyEncoding::UTF_32BE.name.should eq "UTF-32BE"
    end

    it "ISO_8859_1 has name ISO-8859-1" do
      RubyEncoding::ISO_8859_1.name.should eq "ISO-8859-1"
    end

    it "ISO_8859_15 has name ISO-8859-15" do
      RubyEncoding::ISO_8859_15.name.should eq "ISO-8859-15"
    end

    it "WINDOWS_1252 has name Windows-1252" do
      RubyEncoding::WINDOWS_1252.name.should eq "Windows-1252"
    end

    it "KOI8_R has name KOI8-R" do
      RubyEncoding::KOI8_R.name.should eq "KOI8-R"
    end

    it "SHIFT_JIS has name Shift_JIS" do
      RubyEncoding::SHIFT_JIS.name.should eq "Shift_JIS"
    end

    it "EUC_JP has name EUC-JP" do
      RubyEncoding::EUC_JP.name.should eq "EUC-JP"
    end
  end

  # -------------------------------------------------------------------------
  # #ascii_compatible?
  # -------------------------------------------------------------------------

  describe "#ascii_compatible?" do
    it "UTF_8 is ASCII-compatible" do
      RubyEncoding::UTF_8.ascii_compatible?.should be_true
    end

    it "ASCII_8BIT is ASCII-compatible" do
      RubyEncoding::ASCII_8BIT.ascii_compatible?.should be_true
    end

    it "US_ASCII is ASCII-compatible" do
      RubyEncoding::US_ASCII.ascii_compatible?.should be_true
    end

    it "ISO_8859_1 is ASCII-compatible" do
      RubyEncoding::ISO_8859_1.ascii_compatible?.should be_true
    end

    it "WINDOWS_1252 is ASCII-compatible" do
      RubyEncoding::WINDOWS_1252.ascii_compatible?.should be_true
    end

    it "KOI8_R is ASCII-compatible" do
      RubyEncoding::KOI8_R.ascii_compatible?.should be_true
    end

    it "EUC_JP is ASCII-compatible" do
      RubyEncoding::EUC_JP.ascii_compatible?.should be_true
    end

    it "SHIFT_JIS is ASCII-compatible" do
      RubyEncoding::SHIFT_JIS.ascii_compatible?.should be_true
    end

    it "UTF_16LE is NOT ASCII-compatible" do
      RubyEncoding::UTF_16LE.ascii_compatible?.should be_false
    end

    it "UTF_16BE is NOT ASCII-compatible" do
      RubyEncoding::UTF_16BE.ascii_compatible?.should be_false
    end

    it "UTF_32LE is NOT ASCII-compatible" do
      RubyEncoding::UTF_32LE.ascii_compatible?.should be_false
    end

    it "UTF_32BE is NOT ASCII-compatible" do
      RubyEncoding::UTF_32BE.ascii_compatible?.should be_false
    end
  end

  # -------------------------------------------------------------------------
  # #single_byte?
  # -------------------------------------------------------------------------

  describe "#single_byte?" do
    it "ASCII_8BIT is single-byte" do
      RubyEncoding::ASCII_8BIT.single_byte?.should be_true
    end

    it "US_ASCII is single-byte" do
      RubyEncoding::US_ASCII.single_byte?.should be_true
    end

    it "ISO_8859_1 is single-byte" do
      RubyEncoding::ISO_8859_1.single_byte?.should be_true
    end

    it "ISO_8859_2 is single-byte" do
      RubyEncoding::ISO_8859_2.single_byte?.should be_true
    end

    it "ISO_8859_15 is single-byte" do
      RubyEncoding::ISO_8859_15.single_byte?.should be_true
    end

    it "WINDOWS_1252 is single-byte" do
      RubyEncoding::WINDOWS_1252.single_byte?.should be_true
    end

    it "KOI8_R is single-byte" do
      RubyEncoding::KOI8_R.single_byte?.should be_true
    end

    it "KOI8_U is single-byte" do
      RubyEncoding::KOI8_U.single_byte?.should be_true
    end

    it "IBM437 is single-byte" do
      RubyEncoding::IBM437.single_byte?.should be_true
    end

    it "MACROMAN is single-byte" do
      RubyEncoding::MACROMAN.single_byte?.should be_true
    end

    it "TIS_620 is single-byte" do
      RubyEncoding::TIS_620.single_byte?.should be_true
    end

    it "UTF_8 is NOT single-byte" do
      RubyEncoding::UTF_8.single_byte?.should be_false
    end

    it "UTF_16LE is NOT single-byte" do
      RubyEncoding::UTF_16LE.single_byte?.should be_false
    end

    it "EUC_JP is NOT single-byte" do
      RubyEncoding::EUC_JP.single_byte?.should be_false
    end

    it "SHIFT_JIS is NOT single-byte" do
      RubyEncoding::SHIFT_JIS.single_byte?.should be_false
    end

    it "GBK is NOT single-byte" do
      RubyEncoding::GBK.single_byte?.should be_false
    end
  end
end
