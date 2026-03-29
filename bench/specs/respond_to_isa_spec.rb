require_relative '../test_harness'

class Animal
  def speak
    "..."
  end
end

class Dog < Animal
  def fetch
    "fetching!"
  end
end

module Swimmable
  def swim
    "swimming!"
  end
end

class Duck < Animal
  include Swimmable

  def quack
    "quack!"
  end
end

describe "respond_to? constant folding" do
  it "returns true for defined methods" do
    d = Dog.new
    d.respond_to?(:speak).should == true
    d.respond_to?(:fetch).should == true
  end

  it "returns false for undefined methods" do
    d = Dog.new
    d.respond_to?(:quack).should == false
    d.respond_to?(:swim).should == false
  end

  it "works for included module methods" do
    duck = Duck.new
    duck.respond_to?(:swim).should == true
    duck.respond_to?(:quack).should == true
    duck.respond_to?(:speak).should == true
    duck.respond_to?(:fetch).should == false
  end
end

describe "is_a? constant folding" do
  it "returns true for own class" do
    d = Dog.new
    d.is_a?(Dog).should == true
  end

  it "returns true for superclass" do
    d = Dog.new
    d.is_a?(Animal).should == true
  end

  it "returns false for unrelated class" do
    d = Dog.new
    d.is_a?(Duck).should == false
  end

  it "returns true for included module" do
    duck = Duck.new
    duck.is_a?(Swimmable).should == true
  end

  it "returns false for non-included module" do
    d = Dog.new
    d.is_a?(Swimmable).should == false
  end

  it "kind_of? works the same as is_a?" do
    d = Dog.new
    d.kind_of?(Animal).should == true
    d.kind_of?(Duck).should == false
  end
end

puts "#{$spec_pass} passed, #{$spec_fail} failed"
raise "#{$spec_fail} test(s) failed" if $spec_fail > 0
