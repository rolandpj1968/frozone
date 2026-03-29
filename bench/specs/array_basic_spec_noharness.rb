# Array basic spec — test harness loaded via -r flag

describe "Array" do
  describe "#size" do
    it "returns the number of elements" do
      [1, 2, 3].size.should == 3
    end

    it "returns 0 for empty array" do
      [].size.should == 0
    end
  end

  describe "#push" do
    it "appends an element" do
      a = [1, 2]
      a.push(3)
      a.size.should == 3
    end
  end

  describe "#first" do
    it "returns the first element" do
      [5, 6, 7].first.should == 5
    end
  end

  describe "#include?" do
    it "returns true when element exists" do
      [1, 2, 3].include?(2).should == true
    end
  end
end

puts "#{$spec_pass} passed, #{$spec_fail} failed"
