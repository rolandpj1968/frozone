require_relative '../test_harness'

# --- Helper methods and classes (detected as load-phase by --aot) ---

def fib(n)
  return n if n < 2
  fib(n - 1) + fib(n - 2)
end

def greet(name, greeting = "hello")
  "#{greeting} #{name}"
end

def double_each(arr)
  result = []
  arr.each { |x| result << x * 2 }
  result
end

class Point
  def initialize(x, y)
    @x = x
    @y = y
  end

  def x; @x; end
  def y; @y; end

  def distance
    Math.sqrt(@x * @x + @y * @y)
  end
end

# --- Tests (execute phase) ---

describe "if expression" do
  it "evaluates body if expression is true" do
    a = []
    if true
      a << 123
    end
    a.should == [123]
  end

  it "does not evaluate body if expression is false" do
    a = []
    if false
      a << 123
    end
    a.should == []
  end

  it "evaluates else when expression is false" do
    a = []
    if false
      a << 123
    else
      a << 456
    end
    a.should == [456]
  end

  it "returns the value of the last expression" do
    result = if true
      1 + 2
    end
    result.should == 3
  end

  it "handles elsif" do
    x = 2
    result = if x == 1
      "one"
    elsif x == 2
      "two"
    else
      "other"
    end
    result.should == "two"
  end
end

describe "while loop" do
  it "executes body while condition is true" do
    i = 0
    while i < 5
      i += 1
    end
    i.should == 5
  end

  it "does not execute body if condition is initially false" do
    i = 0
    while false
      i += 1
    end
    i.should == 0
  end
end

describe "until loop" do
  it "executes body until condition is true" do
    i = 0
    until i >= 3
      i += 1
    end
    i.should == 3
  end
end

describe "method definition" do
  it "defines callable methods" do
    fib(10).should == 55
  end

  it "handles default arguments" do
    greet("world").should == "hello world"
  end
end

describe "block passing" do
  it "passes blocks to Integer#times" do
    result = []
    3.times { |i| result << i }
    result.should == [0, 1, 2]
  end

  it "works with Array#each" do
    double_each([1, 2, 3]).should == [2, 4, 6]
  end
end

describe "class definition" do
  it "creates instances with ivars" do
    p = Point.new(3, 4)
    p.x.should == 3
    p.y.should == 4
  end

  it "calls methods on instances" do
    p = Point.new(3, 4)
    p.distance.should == 5.0
  end
end

describe "ternary operator" do
  it "returns first value when true" do
    (true ? "yes" : "no").should == "yes"
  end

  it "returns second value when false" do
    (false ? "yes" : "no").should == "no"
  end
end

describe "string interpolation" do
  it "interpolates variables" do
    name = "world"
    "hello #{name}".should == "hello world"
  end

  it "interpolates expressions" do
    "1 + 2 = #{1 + 2}".should == "1 + 2 = 3"
  end
end

describe "case expression" do
  it "matches values" do
    result = case 2
    when 1 then "one"
    when 2 then "two"
    when 3 then "three"
    else "other"
    end
    result.should == "two"
  end
end

puts "#{$spec_pass} passed, #{$spec_fail} failed"
raise "#{$spec_fail} test(s) failed" if $spec_fail > 0
