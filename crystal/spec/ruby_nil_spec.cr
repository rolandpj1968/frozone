require "spec"
require "../src/ruby_nil"

describe RubyNil do
  # -----------------------------------------------------------------------
  # Singleton
  # -----------------------------------------------------------------------

  describe "INSTANCE" do
    it "is a RubyNil" do
      RubyNil::INSTANCE.should be_a(RubyNil)
    end

    it "is the same object every time" do
      RubyNil::INSTANCE.object_id.should eq RubyNil::INSTANCE.object_id
    end
  end

  # -----------------------------------------------------------------------
  # to_s / inspect
  # -----------------------------------------------------------------------

  describe "#to_s" do
    it "returns empty string" do
      RubyNil::INSTANCE.to_s.should eq ""
    end
  end

  describe "#inspect" do
    it "returns 'nil'" do
      RubyNil::INSTANCE.inspect.should eq "nil"
    end
  end

  # -----------------------------------------------------------------------
  # Equality
  # -----------------------------------------------------------------------

  describe "#==" do
    it "nil == nil is true" do
      (RubyNil::INSTANCE == RubyNil::INSTANCE).should be_true
    end

    it "nil == false is false" do
      (RubyNil::INSTANCE == false).should be_false
    end

    it "nil == 0 is false" do
      (RubyNil::INSTANCE == 0).should be_false
    end

    it "nil == empty string is false" do
      (RubyNil::INSTANCE == "").should be_false
    end
  end

  # -----------------------------------------------------------------------
  # to_i
  # -----------------------------------------------------------------------

  describe "#to_i" do
    it "returns RubyInteger(0)" do
      result = RubyNil::INSTANCE.to_i
      result.should be_a(RubyInteger)
      result.to_i64.should eq 0_i64
    end
  end

  # -----------------------------------------------------------------------
  # to_f
  # -----------------------------------------------------------------------

  describe "#to_f" do
    it "returns RubyFloat(0.0)" do
      result = RubyNil::INSTANCE.to_f
      result.should be_a(RubyFloat)
      result.to_f.should eq 0.0
    end
  end

  # -----------------------------------------------------------------------
  # to_a
  # -----------------------------------------------------------------------

  describe "#to_a" do
    it "returns an empty array" do
      result = RubyNil::INSTANCE.to_a
      result.should be_a(Array(RubyNil))
      result.empty?.should be_true
    end
  end

  # -----------------------------------------------------------------------
  # & and |
  # -----------------------------------------------------------------------

  describe "#&" do
    it "nil & true is false" do
      (RubyNil::INSTANCE & true).should be_false
    end

    it "nil & false is false" do
      (RubyNil::INSTANCE & false).should be_false
    end
  end

  describe "#|" do
    it "nil | true is true" do
      (RubyNil::INSTANCE | true).should be_true
    end

    it "nil | false is false" do
      (RubyNil::INSTANCE | false).should be_false
    end
  end

  # -----------------------------------------------------------------------
  # hash
  # -----------------------------------------------------------------------

  describe "#hash" do
    it "returns a UInt64" do
      RubyNil::INSTANCE.hash.should be_a(UInt64)
    end

    it "is deterministic (same value every call)" do
      RubyNil::INSTANCE.hash.should eq RubyNil::INSTANCE.hash
    end

    it "is 0" do
      RubyNil::INSTANCE.hash.should eq 0_u64
    end
  end
end
