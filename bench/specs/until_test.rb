require_relative '../test_harness'

describe "until" do
  it "works" do
    i = 0
    until i >= 3
      i += 1
    end
    i.should == 3
  end
end
puts "#{$spec_pass} passed"
