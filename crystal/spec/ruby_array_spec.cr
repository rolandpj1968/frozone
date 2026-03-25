require "spec"
require "../src/ruby_array"
require "../src/ruby_integer"
require "../src/ruby_string/ruby_string"
require "../src/ruby_nil"
require "../src/ruby_bool"

# Helpers
private def ri(n : Int64) : RubyInteger
  RubyInteger.new(n)
end

private def arr(*items : RubyObject) : RubyArray
  a = RubyArray.new
  items.each { |x| a.push(x) }
  a
end

describe RubyArray do
  describe "#initialize" do
    it "creates an empty array" do
      a = RubyArray.new
      a.length.should eq ri(0)
    end

    it "creates an array with capacity hint" do
      a = RubyArray.new(10)
      a.length.should eq ri(0)
    end
  end

  describe "#length / #size" do
    it "returns the number of elements" do
      a = arr(ri(1), ri(2), ri(3))
      a.length.should eq ri(3)
      a.size.should eq ri(3)
    end
  end

  describe "#empty?" do
    it "returns TRUE for an empty array" do
      RubyArray.new.empty?.should eq RubyBool::TRUE
    end

    it "returns FALSE for a non-empty array" do
      arr(ri(1)).empty?.should eq RubyBool::FALSE
    end
  end

  describe "#[]" do
    it "accesses elements by positive index" do
      a = arr(ri(10), ri(20), ri(30))
      a[0_i64].should eq ri(10)
      a[1_i64].should eq ri(20)
      a[2_i64].should eq ri(30)
    end

    it "supports negative indices" do
      a = arr(ri(10), ri(20), ri(30))
      a[-1_i64].should eq ri(30)
      a[-2_i64].should eq ri(20)
    end

    it "returns nil for out-of-bounds access" do
      a = arr(ri(1))
      a[5_i64].should eq RubyNil::INSTANCE
      a[-5_i64].should eq RubyNil::INSTANCE
    end

    it "supports RubyInteger index" do
      a = arr(ri(10), ri(20))
      a[ri(1)].should eq ri(20)
    end
  end

  describe "#[]=" do
    it "sets elements by positive index" do
      a = arr(ri(1), ri(2), ri(3))
      a[1_i64] = ri(99)
      a[1_i64].should eq ri(99)
    end

    it "extends array with nils for out-of-range assignment" do
      a = RubyArray.new
      a[2_i64] = ri(42)
      a[0_i64].should eq RubyNil::INSTANCE
      a[1_i64].should eq RubyNil::INSTANCE
      a[2_i64].should eq ri(42)
      a.length.should eq ri(3)
    end

    it "raises for negative out-of-bounds index" do
      a = arr(ri(1))
      expect_raises(IndexError) { a[-5_i64] = ri(0) }
    end
  end

  describe "#push / #pop" do
    it "pushes and pops elements" do
      a = RubyArray.new
      a.push(ri(1))
      a.push(ri(2))
      a.length.should eq ri(2)
      a.pop.should eq ri(2)
      a.pop.should eq ri(1)
      a.pop.should eq RubyNil::INSTANCE
    end
  end

  describe "#shift / #unshift" do
    it "shifts from the front" do
      a = arr(ri(1), ri(2), ri(3))
      a.shift.should eq ri(1)
      a.length.should eq ri(2)
    end

    it "unshifts to the front" do
      a = arr(ri(2), ri(3))
      a.unshift(ri(1))
      a[0_i64].should eq ri(1)
      a.length.should eq ri(3)
    end

    it "returns nil when shifting empty array" do
      RubyArray.new.shift.should eq RubyNil::INSTANCE
    end
  end

  describe "#concat" do
    it "appends another array in place" do
      a = arr(ri(1), ri(2))
      b = arr(ri(3), ri(4))
      a.concat(b)
      a.length.should eq ri(4)
      a[2_i64].should eq ri(3)
    end
  end

  describe "#+" do
    it "returns a new concatenated array" do
      a = arr(ri(1), ri(2))
      b = arr(ri(3), ri(4))
      c = a + b
      c.length.should eq ri(4)
      a.length.should eq ri(2) # unchanged
    end
  end

  describe "#clear" do
    it "removes all elements" do
      a = arr(ri(1), ri(2), ri(3))
      a.clear
      a.length.should eq ri(0)
    end
  end

  describe "#first / #last" do
    it "returns the first/last element" do
      a = arr(ri(10), ri(20), ri(30))
      a.first.should eq ri(10)
      a.last.should eq ri(30)
    end

    it "returns nil on empty array" do
      RubyArray.new.first.should eq RubyNil::INSTANCE
      RubyArray.new.last.should eq RubyNil::INSTANCE
    end
  end

  describe "#reverse" do
    it "returns a reversed copy" do
      a = arr(ri(1), ri(2), ri(3))
      r = a.reverse
      r[0_i64].should eq ri(3)
      r[2_i64].should eq ri(1)
      a[0_i64].should eq ri(1) # original unchanged
    end
  end

  describe "#flatten" do
    it "flattens nested arrays" do
      inner = arr(ri(2), ri(3))
      outer = RubyArray.new
      outer.push(ri(1))
      outer.push(inner)
      outer.push(ri(4))
      flat = outer.flatten
      flat.length.should eq ri(4)
      flat[0_i64].should eq ri(1)
      flat[1_i64].should eq ri(2)
      flat[3_i64].should eq ri(4)
    end

    it "returns a copy for already-flat arrays" do
      a = arr(ri(1), ri(2))
      flat = a.flatten
      flat.length.should eq ri(2)
    end
  end

  describe "#include?" do
    it "returns TRUE when element is present" do
      a = arr(ri(1), ri(2), ri(3))
      a.include?(ri(2)).should eq RubyBool::TRUE
    end

    it "returns FALSE when element is absent" do
      a = arr(ri(1), ri(2))
      a.include?(ri(99)).should eq RubyBool::FALSE
    end
  end

  describe "#each" do
    it "iterates over each element" do
      a = arr(ri(1), ri(2), ri(3))
      collected = [] of RubyObject
      a.each { |el| collected << el }
      collected.size.should eq 3
      collected[0].should eq ri(1)
      collected[2].should eq ri(3)
    end

    it "does nothing for an empty array" do
      count = 0
      RubyArray.new.each { |_| count += 1 }
      count.should eq 0
    end
  end

  describe "#map" do
    it "transforms elements into a new array" do
      a = arr(ri(1), ri(2), ri(3))
      b = a.map { |el| ri(el.as(RubyInteger).to_i64 * 2) }
      b.length.should eq ri(3)
      b[0_i64].should eq ri(2)
      b[1_i64].should eq ri(4)
      b[2_i64].should eq ri(6)
    end

    it "does not mutate the original" do
      a = arr(ri(1), ri(2))
      a.map { |el| ri(99_i64) }
      a[0_i64].should eq ri(1)
    end
  end

  describe "#select" do
    it "keeps elements matching the predicate" do
      a = arr(ri(1), ri(2), ri(3), ri(4))
      b = a.select { |el| el.as(RubyInteger).to_i64.even? }
      b.length.should eq ri(2)
      b[0_i64].should eq ri(2)
      b[1_i64].should eq ri(4)
    end
  end

  describe "#reject" do
    it "keeps elements not matching the predicate" do
      a = arr(ri(1), ri(2), ri(3), ri(4))
      b = a.reject { |el| el.as(RubyInteger).to_i64.even? }
      b.length.should eq ri(2)
      b[0_i64].should eq ri(1)
      b[1_i64].should eq ri(3)
    end
  end

  describe "#compact" do
    it "removes nil elements" do
      a = RubyArray.new
      a.push(ri(1))
      a.push(RubyNil::INSTANCE)
      a.push(ri(2))
      a.push(RubyNil::INSTANCE)
      b = a.compact
      b.length.should eq ri(2)
      b[0_i64].should eq ri(1)
      b[1_i64].should eq ri(2)
    end

    it "returns same-length array when no nils present" do
      a = arr(ri(1), ri(2), ri(3))
      a.compact.length.should eq ri(3)
    end
  end

  describe "#zip" do
    it "pairs elements from two arrays" do
      a = arr(ri(1), ri(2), ri(3))
      b = arr(ri(10), ri(20), ri(30))
      z = a.zip(b)
      z.length.should eq ri(3)
      pair0 = z[0_i64].as(RubyArray)
      pair0[0_i64].should eq ri(1)
      pair0[1_i64].should eq ri(10)
      pair2 = z[2_i64].as(RubyArray)
      pair2[0_i64].should eq ri(3)
      pair2[1_i64].should eq ri(30)
    end

    it "pads missing other elements with nil" do
      a = arr(ri(1), ri(2))
      b = arr(ri(10))
      z = a.zip(b)
      z.length.should eq ri(2)
      pair1 = z[1_i64].as(RubyArray)
      pair1[0_i64].should eq ri(2)
      pair1[1_i64].should eq RubyNil::INSTANCE
    end
  end

  describe "#uniq" do
    it "removes duplicates" do
      a = arr(ri(1), ri(2), ri(1), ri(3), ri(2))
      u = a.uniq
      u.length.should eq ri(3)
      u.include?(ri(1)).should eq RubyBool::TRUE
      u.include?(ri(2)).should eq RubyBool::TRUE
      u.include?(ri(3)).should eq RubyBool::TRUE
    end
  end

  describe "#==" do
    it "returns true for equal arrays" do
      a = arr(ri(1), ri(2))
      b = arr(ri(1), ri(2))
      (a == b).should be_true
    end

    it "returns false for different arrays" do
      a = arr(ri(1), ri(2))
      b = arr(ri(1), ri(3))
      (a == b).should be_false
    end

    it "returns false for different-length arrays" do
      a = arr(ri(1), ri(2))
      b = arr(ri(1))
      (a == b).should be_false
    end

    it "returns false when compared to non-array RubyObject" do
      a = arr(ri(1))
      (a == RubyNil::INSTANCE).should be_false
    end
  end

  describe "#hash" do
    it "returns the same value for equal arrays" do
      a = arr(ri(1), ri(2))
      b = arr(ri(1), ri(2))
      a.hash.should eq b.hash
    end

    it "returns different values for different arrays (usually)" do
      a = arr(ri(1), ri(2))
      b = arr(ri(2), ri(1))
      a.hash.should_not eq b.hash
    end
  end

  describe "#inspect / #to_s" do
    it "formats as Ruby array literal" do
      a = arr(ri(1), ri(2), ri(3))
      a.inspect.should eq "[1, 2, 3]"
      a.to_s.should eq "[1, 2, 3]"
    end

    it "formats empty array" do
      RubyArray.new.inspect.should eq "[]"
    end
  end

  describe "RubyObject base" do
    it "inherits from RubyObject" do
      a = RubyArray.new
      a.should be_a(RubyObject)
    end

    it "truthy? is true" do
      RubyArray.new.truthy?.should be_true
    end

    it "ruby_nil? is false" do
      RubyArray.new.ruby_nil?.should be_false
    end

    it "not returns RubyBool::FALSE" do
      RubyArray.new.not.should eq RubyBool::FALSE
    end
  end
end
