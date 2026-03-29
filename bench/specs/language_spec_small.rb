require_relative '../test_harness'

def fib(n)
  return n if n < 2
  fib(n - 1) + fib(n - 2)
end

class Point
  def initialize(x, y)
    @x = x
    @y = y
  end
  def x; @x; end
  def y; @y; end
end

describe "if expression" do
  it "evaluates body if true" do
    a = []
    if true
      a << 123
    end
    a.should == [123]
  end

  it "evaluates else when false" do
    a = []
    if false
      a << 123
    else
      a << 456
    end
    a.should == [456]
  end
end

describe "while loop" do
  it "loops while true" do
    i = 0
    while i < 5
      i += 1
    end
    i.should == 5
  end
end

describe "until loop" do
  it "loops until true" do
    i = 0
    until i >= 3
      i += 1
    end
    i.should == 3
  end
end

describe "method calls" do
  it "calls recursive methods" do
    fib(10).should == 55
  end
end

describe "class instances" do
  it "creates instances with ivars" do
    p = Point.new(3, 4)
    p.x.should == 3
    p.y.should == 4
  end
end

describe "ternary" do
  it "returns correct branch" do
    (true ? "yes" : "no").should == "yes"
    (false ? "yes" : "no").should == "no"
  end
end

puts "#{$spec_pass} passed, #{$spec_fail} failed"
puts $spec_errors.inspect if $spec_fail > 0
