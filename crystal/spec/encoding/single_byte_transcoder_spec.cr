require "spec"
require "../../src/encoding/single_byte_transcoder"

describe Encoding::SingleByte do
  describe ".byte_to_ucs" do
    context "ISO-8859-1" do
      it "maps ASCII byte 0x41 ('A') to codepoint 0x41" do
        Encoding::SingleByte.byte_to_ucs(0x41_u8, "ISO-8859-1").should eq 0x41
      end

      it "maps byte 0xE9 to codepoint 0xE9 (é)" do
        Encoding::SingleByte.byte_to_ucs(0xE9_u8, "ISO-8859-1").should eq 0xE9
      end

      it "maps byte 0xFF to codepoint 0xFF (ÿ)" do
        Encoding::SingleByte.byte_to_ucs(0xFF_u8, "ISO-8859-1").should eq 0xFF
      end
    end

    context "WINDOWS-1252" do
      it "maps byte 0x80 to codepoint 0x20AC (euro sign €)" do
        Encoding::SingleByte.byte_to_ucs(0x80_u8, "WINDOWS-1252").should eq 0x20AC
      end

      it "maps ASCII byte 0x41 ('A') to codepoint 0x41" do
        Encoding::SingleByte.byte_to_ucs(0x41_u8, "WINDOWS-1252").should eq 0x41
      end
    end

    context "KOI8-R" do
      # KOI8-R byte 0xC1 maps to U+0430 (Cyrillic small letter 'a')
      it "maps byte 0xC1 to codepoint 0x430 (Cyrillic small letter a)" do
        Encoding::SingleByte.byte_to_ucs(0xC1_u8, "KOI8-R").should eq 0x430
      end

      # KOI8-R byte 0x80 maps to U+2500 (box drawing light horizontal)
      it "maps byte 0x80 to codepoint 0x2500" do
        Encoding::SingleByte.byte_to_ucs(0x80_u8, "KOI8-R").should eq 0x2500
      end
    end

    context "unknown encoding" do
      it "returns -1 for an unknown encoding" do
        Encoding::SingleByte.byte_to_ucs(0x41_u8, "DOES-NOT-EXIST").should eq(-1)
      end
    end
  end

  describe ".ucs_to_byte" do
    context "ISO-8859-1 round-trips" do
      it "round-trips byte 0x41 ('A')" do
        Encoding::SingleByte.ucs_to_byte(0x41, "ISO-8859-1").should eq 0x41
      end

      it "round-trips byte 0xE9 (é, U+00E9)" do
        Encoding::SingleByte.ucs_to_byte(0xE9, "ISO-8859-1").should eq 0xE9
      end

      it "round-trips byte 0xFF (ÿ, U+00FF)" do
        Encoding::SingleByte.ucs_to_byte(0xFF, "ISO-8859-1").should eq 0xFF
      end
    end

    context "WINDOWS-1252 round-trips" do
      it "round-trips byte 0x80 (€, U+20AC)" do
        Encoding::SingleByte.ucs_to_byte(0x20AC, "WINDOWS-1252").should eq 0x80
      end
    end

    context "KOI8-R round-trips" do
      it "round-trips byte 0xC1 (Cyrillic small a, U+0430)" do
        Encoding::SingleByte.ucs_to_byte(0x430, "KOI8-R").should eq 0xC1
      end
    end

    context "invalid/unmapped codepoints" do
      # U+20AC is the euro sign — not in ISO-8859-1
      it "returns -1 for codepoint not in encoding (euro in ISO-8859-1)" do
        Encoding::SingleByte.ucs_to_byte(0x20AC, "ISO-8859-1").should eq(-1)
      end
    end

    context "unknown encoding" do
      it "returns -1 for an unknown encoding" do
        Encoding::SingleByte.ucs_to_byte(0x41, "DOES-NOT-EXIST").should eq(-1)
      end
    end
  end

  describe "ENCODINGS constant" do
    it "includes ISO-8859-1" do
      Encoding::SingleByte::ENCODINGS.includes?("ISO-8859-1").should be_true
    end

    it "includes WINDOWS-1252" do
      Encoding::SingleByte::ENCODINGS.includes?("WINDOWS-1252").should be_true
    end

    it "includes KOI8-R" do
      Encoding::SingleByte::ENCODINGS.includes?("KOI8-R").should be_true
    end

    it "has 53 encodings" do
      Encoding::SingleByte::ENCODINGS.size.should eq 53
    end
  end
end
