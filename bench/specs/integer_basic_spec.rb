require_relative '../test_harness'

describe "Integer" do
  describe "#+" do
    it "adds two integers" do
      (1 + 2).should == 3
    end

    it "adds negative integers" do
      (-5 + 3).should == -2
    end
  end

  describe "#*" do
    it "multiplies integers" do
      (6 * 7).should == 42
    end
  end

  describe "#==" do
    it "returns true for equal values" do
      (42 == 42).should == true
    end

    it "returns false for unequal values" do
      (42 == 43).should == false
    end
  end

  describe "#abs" do
    it "returns absolute value" do
      (-5).abs.should == 5
      5.abs.should == 5
    end
  end

  describe "#zero?" do
    it "returns true for zero" do
      0.zero?.should == true
    end

    it "returns false for non-zero" do
      1.zero?.should == false
    end
  end

  describe "#even? and #odd?" do
    it "identifies even numbers" do
      4.even?.should == true
      3.even?.should == false
    end

    it "identifies odd numbers" do
      3.odd?.should == true
      4.odd?.should == false
    end
  end

  describe "#to_f" do
    it "converts to float" do
      (3.to_f).should == 3.0
    end
  end
end

describe "String" do
  describe "#length" do
    it "returns string length" do
      "hello".length.should == 5
    end

    it "returns 0 for empty string" do
      "".length.should == 0
    end
  end

  describe "#+" do
    it "concatenates strings" do
      ("hello" + " world").should == "hello world"
    end
  end

  describe "#upcase" do
    it "upcases the string" do
      "hello".upcase.should == "HELLO"
    end
  end

  describe "#downcase" do
    it "downcases the string" do
      "HELLO".downcase.should == "hello"
    end
  end

  describe "#include?" do
    it "checks substring presence" do
      "hello world".include?("world").should == true
      "hello world".include?("xyz").should == false
    end
  end
end

puts "#{$spec_pass} passed, #{$spec_fail} failed"
raise "#{$spec_fail} test(s) failed" if $spec_fail > 0
