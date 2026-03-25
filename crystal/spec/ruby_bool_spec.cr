require "spec"
require "../src/ruby_bool"

describe RubyBool do
  # -----------------------------------------------------------------------
  # Singletons
  # -----------------------------------------------------------------------

  describe "TRUE / FALSE" do
    it "TRUE is a RubyBool" do
      RubyBool::TRUE.should be_a(RubyBool)
    end

    it "FALSE is a RubyBool" do
      RubyBool::FALSE.should be_a(RubyBool)
    end

    it "TRUE.value is true" do
      RubyBool::TRUE.value.should be_true
    end

    it "FALSE.value is false" do
      RubyBool::FALSE.value.should be_false
    end

    it "TRUE and FALSE are different objects" do
      RubyBool::TRUE.object_id.should_not eq RubyBool::FALSE.object_id
    end
  end

  # -----------------------------------------------------------------------
  # to_s / inspect
  # -----------------------------------------------------------------------

  describe "#to_s" do
    it "true.to_s => 'true'" do
      RubyBool::TRUE.to_s.should eq "true"
    end

    it "false.to_s => 'false'" do
      RubyBool::FALSE.to_s.should eq "false"
    end
  end

  describe "#inspect" do
    it "true.inspect => 'true'" do
      RubyBool::TRUE.inspect.should eq "true"
    end

    it "false.inspect => 'false'" do
      RubyBool::FALSE.inspect.should eq "false"
    end
  end

  # -----------------------------------------------------------------------
  # Equality
  # -----------------------------------------------------------------------

  describe "#==" do
    it "TRUE == TRUE is true" do
      (RubyBool::TRUE == RubyBool::TRUE).should be_true
    end

    it "FALSE == FALSE is true" do
      (RubyBool::FALSE == RubyBool::FALSE).should be_true
    end

    it "TRUE == FALSE is false" do
      (RubyBool::TRUE == RubyBool::FALSE).should be_false
    end

    it "FALSE == TRUE is false" do
      (RubyBool::FALSE == RubyBool::TRUE).should be_false
    end

    it "TRUE == non-RubyBool is false" do
      (RubyBool::TRUE == 1).should be_false
    end

    it "FALSE == non-RubyBool is false" do
      (RubyBool::FALSE == nil).should be_false
    end
  end

  # -----------------------------------------------------------------------
  # Logical AND
  # -----------------------------------------------------------------------

  describe "#&" do
    it "true & true => TRUE" do
      result = RubyBool::TRUE & RubyBool::TRUE
      result.should eq RubyBool::TRUE
    end

    it "true & false => FALSE" do
      result = RubyBool::TRUE & RubyBool::FALSE
      result.should eq RubyBool::FALSE
    end

    it "false & true => FALSE" do
      result = RubyBool::FALSE & RubyBool::TRUE
      result.should eq RubyBool::FALSE
    end

    it "false & false => FALSE" do
      result = RubyBool::FALSE & RubyBool::FALSE
      result.should eq RubyBool::FALSE
    end
  end

  # -----------------------------------------------------------------------
  # Logical OR
  # -----------------------------------------------------------------------

  describe "#|" do
    it "true | true => TRUE" do
      result = RubyBool::TRUE | RubyBool::TRUE
      result.should eq RubyBool::TRUE
    end

    it "true | false => TRUE" do
      result = RubyBool::TRUE | RubyBool::FALSE
      result.should eq RubyBool::TRUE
    end

    it "false | true => TRUE" do
      result = RubyBool::FALSE | RubyBool::TRUE
      result.should eq RubyBool::TRUE
    end

    it "false | false => FALSE" do
      result = RubyBool::FALSE | RubyBool::FALSE
      result.should eq RubyBool::FALSE
    end
  end

  # -----------------------------------------------------------------------
  # Logical XOR
  # -----------------------------------------------------------------------

  describe "#^" do
    it "true ^ true => FALSE" do
      result = RubyBool::TRUE ^ RubyBool::TRUE
      result.should eq RubyBool::FALSE
    end

    it "true ^ false => TRUE" do
      result = RubyBool::TRUE ^ RubyBool::FALSE
      result.should eq RubyBool::TRUE
    end

    it "false ^ true => TRUE" do
      result = RubyBool::FALSE ^ RubyBool::TRUE
      result.should eq RubyBool::TRUE
    end

    it "false ^ false => FALSE" do
      result = RubyBool::FALSE ^ RubyBool::FALSE
      result.should eq RubyBool::FALSE
    end
  end

  # -----------------------------------------------------------------------
  # Logical NOT (not method — ! is a Crystal pseudo-method)
  # -----------------------------------------------------------------------

  describe "#not" do
    it "TRUE.not => FALSE" do
      RubyBool::TRUE.not.should eq RubyBool::FALSE
    end

    it "FALSE.not => TRUE" do
      RubyBool::FALSE.not.should eq RubyBool::TRUE
    end

    it "TRUE.not.not => TRUE" do
      RubyBool::TRUE.not.not.should eq RubyBool::TRUE
    end
  end

  # -----------------------------------------------------------------------
  # hash
  # -----------------------------------------------------------------------

  describe "#hash" do
    it "returns a UInt64" do
      RubyBool::TRUE.hash.should be_a(UInt64)
    end

    it "TRUE and FALSE have different hashes" do
      RubyBool::TRUE.hash.should_not eq RubyBool::FALSE.hash
    end

    it "TRUE hash is consistent" do
      RubyBool::TRUE.hash.should eq RubyBool::TRUE.hash
    end

    it "FALSE hash is consistent" do
      RubyBool::FALSE.hash.should eq RubyBool::FALSE.hash
    end

    it "TRUE.hash is 1" do
      RubyBool::TRUE.hash.should eq 1_u64
    end

    it "FALSE.hash is 0" do
      RubyBool::FALSE.hash.should eq 0_u64
    end
  end
end
