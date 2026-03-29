# Array basic spec — no Frozone.compile! needed when using --aot
require_relative '../test_harness'

describe "Array" do
  describe "#size" do
    it "returns the number of elements" do
      [1, 2, 3].size.should == 3
    end

    it "returns 0 for empty array" do
      [].size.should == 0
    end
  end

  describe "#[]" do
    it "returns the element at index" do
      a = [10, 20, 30]
      a[0].should == 10
      a[1].should == 20
      a[2].should == 30
    end
  end

  describe "#push" do
    it "appends an element" do
      a = [1, 2]
      a.push(3)
      a.size.should == 3
      a[2].should == 3
    end
  end

  describe "#+" do
    it "concatenates arrays" do
      a = [1, 2] + [3, 4]
      a.size.should == 4
      a[0].should == 1
      a[3].should == 4
    end
  end

  describe "#first" do
    it "returns the first element" do
      [5, 6, 7].first.should == 5
    end
  end

  describe "#last" do
    it "returns the last element" do
      [5, 6, 7].last.should == 7
    end
  end

  describe "#include?" do
    it "returns true when element exists" do
      [1, 2, 3].include?(2).should == true
    end

    it "returns false when element missing" do
      [1, 2, 3].include?(5).should == false
    end
  end
end

puts "#{$spec_pass} passed, #{$spec_fail} failed"
raise "#{$spec_fail} test(s) failed" if $spec_fail > 0
