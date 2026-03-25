require "spec"
require "../src/ruby_float"  # pulls in ruby_integer; needed for RubyInteger#to_f

# Convenience helpers
private def ri(v : Int64) : RubyInteger
  RubyInteger.new(v)
end

private def ri(v : Int32) : RubyInteger
  RubyInteger.new(v.to_i64)
end

describe RubyInteger do
  # -----------------------------------------------------------------------
  # Construction
  # -----------------------------------------------------------------------

  describe ".new" do
    it "creates a small integer from Int64" do
      n = RubyInteger.new(42_i64)
      n.small?.should be_true
      n.to_i64.should eq 42_i64
    end

    it "creates an integer from Int32" do
      n = RubyInteger.new(7)
      n.to_i64.should eq 7_i64
    end

    it "creates an integer from BigInt" do
      big = BigInt.new("99999999999999999999")
      n = RubyInteger.new(big)
      n.small?.should be_false
    end
  end

  describe ".from_string" do
    it "parses a decimal string" do
      n = RubyInteger.from_string("12345")
      n.to_i64.should eq 12345_i64
    end

    it "parses a negative decimal string" do
      n = RubyInteger.from_string("-99")
      n.to_i64.should eq -99_i64
    end

    it "parses a hex string (base 16)" do
      n = RubyInteger.from_string("ff", 16)
      n.to_i64.should eq 255_i64
    end

    it "parses a binary string (base 2)" do
      n = RubyInteger.from_string("1010", 2)
      n.to_i64.should eq 10_i64
    end

    it "parses a large number into BigInt" do
      n = RubyInteger.from_string("99999999999999999999")
      n.small?.should be_false
    end

    it "raises ArgumentError for invalid input" do
      expect_raises(ArgumentError) { RubyInteger.from_string("abc") }
    end
  end

  # -----------------------------------------------------------------------
  # Conversion
  # -----------------------------------------------------------------------

  describe "#to_i64" do
    it "returns the Int64 value for small integers" do
      ri(42_i64).to_i64.should eq 42_i64
    end

    it "raises OverflowError for large BigInt" do
      huge = RubyInteger.new(BigInt.new("99999999999999999999"))
      expect_raises(OverflowError) { huge.to_i64 }
    end
  end

  describe "#to_big" do
    it "always succeeds for small integers" do
      ri(7_i64).to_big.should eq BigInt.new(7)
    end

    it "returns the BigInt directly for bignum" do
      big = BigInt.new("99999999999999999999")
      RubyInteger.new(big).to_big.should eq big
    end
  end

  describe "#to_f64" do
    it "converts small integers to Float64" do
      ri(3_i64).to_f64.should eq 3.0_f64
    end

    it "converts negative integers to Float64" do
      ri(-7_i64).to_f64.should eq -7.0_f64
    end
  end

  describe "#to_f" do
    it "returns a RubyFloat wrapping the value" do
      f = ri(3_i64).to_f
      f.should be_a(RubyFloat)
      f.raw.should eq 3.0_f64
    end

    it "converts negative integers correctly" do
      f = ri(-5_i64).to_f
      f.should be_a(RubyFloat)
      f.raw.should eq -5.0_f64
    end

    it "round-trips via to_i" do
      ri(42_i64).to_f.to_i.to_i64.should eq 42_i64
    end
  end

  describe "#to_s" do
    it "converts to decimal by default" do
      ri(255_i64).to_s.should eq "255"
    end

    it "converts to binary (base 2)" do
      ri(10_i64).to_s(2).should eq "1010"
    end

    it "converts to octal (base 8)" do
      ri(8_i64).to_s(8).should eq "10"
    end

    it "converts to hex (base 16)" do
      ri(255_i64).to_s(16).should eq "ff"
    end

    it "handles negative numbers" do
      ri(-42_i64).to_s.should eq "-42"
    end
  end

  # -----------------------------------------------------------------------
  # Basic arithmetic
  # -----------------------------------------------------------------------

  describe "#+" do
    it "adds two small integers" do
      (ri(3_i64) + ri(4_i64)).to_i64.should eq 7_i64
    end

    it "produces a negative result" do
      (ri(-5_i64) + ri(3_i64)).to_i64.should eq -2_i64
    end

    it "promotes to BigInt on overflow" do
      max = RubyInteger.new(Int64::MAX)
      one = RubyInteger.new(1_i64)
      result = max + one
      result.small?.should be_false
      result.to_big.should eq BigInt.new(Int64::MAX) + 1
    end
  end

  describe "#-" do
    it "subtracts two small integers" do
      (ri(10_i64) - ri(3_i64)).to_i64.should eq 7_i64
    end

    it "promotes to BigInt on underflow" do
      min = RubyInteger.new(Int64::MIN)
      one = RubyInteger.new(1_i64)
      result = min - one
      result.small?.should be_false
    end
  end

  describe "#*" do
    it "multiplies two small integers" do
      (ri(6_i64) * ri(7_i64)).to_i64.should eq 42_i64
    end

    it "promotes to BigInt on overflow" do
      max = RubyInteger.new(Int64::MAX)
      two = RubyInteger.new(2_i64)
      result = max * two
      result.small?.should be_false
      result.to_big.should eq BigInt.new(Int64::MAX) * 2
    end
  end

  describe "#/" do
    it "performs integer division" do
      (ri(10_i64) / ri(3_i64)).to_i64.should eq 3_i64
    end

    it "truncates toward negative infinity for negative dividend" do
      # Ruby: -7 / 2 => -4  (floor division)
      (ri(-7_i64) / ri(2_i64)).to_i64.should eq -4_i64
    end

    it "truncates toward negative infinity for negative divisor" do
      # Ruby: 7 / -2 => -4
      (ri(7_i64) / ri(-2_i64)).to_i64.should eq -4_i64
    end

    it "divides evenly with no adjustment needed" do
      # -6 / 2 => -3 (exact, no adjustment)
      (ri(-6_i64) / ri(2_i64)).to_i64.should eq -3_i64
    end

    it "raises DivisionByZeroError for zero divisor" do
      expect_raises(DivisionByZeroError) { ri(5_i64) / ri(0_i64) }
    end
  end

  describe "#%" do
    it "computes modulo with positive operands" do
      (ri(10_i64) % ri(3_i64)).to_i64.should eq 1_i64
    end

    it "result has sign of divisor: -7 % 3 => 2" do
      (ri(-7_i64) % ri(3_i64)).to_i64.should eq 2_i64
    end

    it "result has sign of divisor: 7 % -3 => -2" do
      (ri(7_i64) % ri(-3_i64)).to_i64.should eq -2_i64
    end

    it "returns 0 for exact division" do
      (ri(6_i64) % ri(3_i64)).to_i64.should eq 0_i64
    end

    it "raises DivisionByZeroError for zero divisor" do
      expect_raises(DivisionByZeroError) { ri(5_i64) % ri(0_i64) }
    end
  end

  describe "#**" do
    it "raises to a positive power" do
      (ri(2_i64) ** ri(10_i64)).to_i64.should eq 1024_i64
    end

    it "any base to the zero power is 1" do
      (ri(99_i64) ** ri(0_i64)).to_i64.should eq 1_i64
    end

    it "0 ** 0 is 1" do
      (ri(0_i64) ** ri(0_i64)).to_i64.should eq 1_i64
    end

    it "negative exponent yields 0 for integers" do
      (ri(2_i64) ** ri(-1_i64)).to_i64.should eq 0_i64
    end

    it "large exponent produces a BigInt" do
      result = ri(2_i64) ** ri(100_i64)
      result.small?.should be_false
      result.to_big.should eq BigInt.new(2) ** 100
    end
  end

  describe "#-@" do
    it "negates a positive integer" do
      (-ri(5_i64)).to_i64.should eq -5_i64
    end

    it "negates a negative integer" do
      (-ri(-5_i64)).to_i64.should eq 5_i64
    end

    it "negates zero" do
      (-ri(0_i64)).to_i64.should eq 0_i64
    end
  end

  describe "#abs" do
    it "returns absolute value of positive" do
      ri(7_i64).abs.to_i64.should eq 7_i64
    end

    it "returns absolute value of negative" do
      ri(-7_i64).abs.to_i64.should eq 7_i64
    end

    it "returns 0 for zero" do
      ri(0_i64).abs.to_i64.should eq 0_i64
    end
  end

  # -----------------------------------------------------------------------
  # Bitwise operations
  # -----------------------------------------------------------------------

  describe "#&" do
    it "bitwise AND" do
      (ri(0b1100_i64) & ri(0b1010_i64)).to_i64.should eq 0b1000_i64
    end

    it "AND with zero yields zero" do
      (ri(0xFF_i64) & ri(0_i64)).to_i64.should eq 0_i64
    end
  end

  describe "#|" do
    it "bitwise OR" do
      (ri(0b1100_i64) | ri(0b1010_i64)).to_i64.should eq 0b1110_i64
    end
  end

  describe "#^" do
    it "bitwise XOR" do
      (ri(0b1100_i64) ^ ri(0b1010_i64)).to_i64.should eq 0b0110_i64
    end
  end

  describe "#~" do
    it "bitwise NOT of 0 is -1" do
      (~ri(0_i64)).to_i64.should eq -1_i64
    end

    it "bitwise NOT of 5 is -6" do
      (~ri(5_i64)).to_i64.should eq -6_i64
    end

    it "bitwise NOT of -1 is 0" do
      (~ri(-1_i64)).to_i64.should eq 0_i64
    end
  end

  describe "#<<" do
    it "left shift" do
      (ri(1_i64) << ri(4_i64)).to_i64.should eq 16_i64
    end

    it "left shift of 255 by 8" do
      (ri(255_i64) << ri(8_i64)).to_i64.should eq 65280_i64
    end

    it "negative shift delegates to right shift" do
      (ri(16_i64) << ri(-2_i64)).to_i64.should eq 4_i64
    end
  end

  describe "#>>" do
    it "right shift" do
      (ri(16_i64) >> ri(2_i64)).to_i64.should eq 4_i64
    end

    it "arithmetic right shift preserves sign for negative" do
      # BigInt right shift is arithmetic
      result = ri(-8_i64) >> ri(1_i64)
      result.to_i64.should eq -4_i64
    end

    it "negative shift delegates to left shift" do
      (ri(4_i64) >> ri(-2_i64)).to_i64.should eq 16_i64
    end
  end

  # -----------------------------------------------------------------------
  # Comparison
  # -----------------------------------------------------------------------

  describe "#<=>" do
    it "returns 0 for equal values" do
      (ri(5_i64) <=> ri(5_i64)).should eq 0
    end

    it "returns negative when less" do
      (ri(3_i64) <=> ri(5_i64)).should be < 0
    end

    it "returns positive when greater" do
      (ri(7_i64) <=> ri(5_i64)).should be > 0
    end
  end

  describe "#==" do
    it "is true for equal values" do
      (ri(42_i64) == ri(42_i64)).should be_true
    end

    it "is false for different values" do
      (ri(42_i64) == ri(43_i64)).should be_false
    end

    it "compares Int64 and BigInt correctly" do
      a = ri(42_i64)
      b = RubyInteger.new(BigInt.new(42))
      (a == b).should be_true
    end
  end

  describe "#< #<= #> #>=" do
    it "< is correct" do
      (ri(3_i64) < ri(5_i64)).should be_true
      (ri(5_i64) < ri(3_i64)).should be_false
    end

    it "<= is correct" do
      (ri(5_i64) <= ri(5_i64)).should be_true
      (ri(4_i64) <= ri(5_i64)).should be_true
      (ri(6_i64) <= ri(5_i64)).should be_false
    end

    it "> is correct" do
      (ri(5_i64) > ri(3_i64)).should be_true
      (ri(3_i64) > ri(5_i64)).should be_false
    end

    it ">= is correct" do
      (ri(5_i64) >= ri(5_i64)).should be_true
      (ri(6_i64) >= ri(5_i64)).should be_true
      (ri(4_i64) >= ri(5_i64)).should be_false
    end
  end

  # -----------------------------------------------------------------------
  # Predicates
  # -----------------------------------------------------------------------

  describe "#zero?" do
    it "is true for 0" do
      ri(0_i64).zero?.should be_true
    end

    it "is false for non-zero" do
      ri(1_i64).zero?.should be_false
      ri(-1_i64).zero?.should be_false
    end
  end

  describe "#positive?" do
    it "is true for positive" do
      ri(1_i64).positive?.should be_true
    end

    it "is false for zero" do
      ri(0_i64).positive?.should be_false
    end

    it "is false for negative" do
      ri(-1_i64).positive?.should be_false
    end
  end

  describe "#negative?" do
    it "is true for negative" do
      ri(-1_i64).negative?.should be_true
    end

    it "is false for zero" do
      ri(0_i64).negative?.should be_false
    end

    it "is false for positive" do
      ri(1_i64).negative?.should be_false
    end
  end

  describe "#odd? / #even?" do
    it "odd? is true for odd numbers" do
      ri(3_i64).odd?.should be_true
      ri(-5_i64).odd?.should be_true
    end

    it "odd? is false for even numbers" do
      ri(4_i64).odd?.should be_false
      ri(0_i64).odd?.should be_false
    end

    it "even? is true for even numbers" do
      ri(4_i64).even?.should be_true
      ri(0_i64).even?.should be_true
    end

    it "even? is false for odd numbers" do
      ri(3_i64).even?.should be_false
    end
  end

  # -----------------------------------------------------------------------
  # Number theory
  # -----------------------------------------------------------------------

  describe "#divmod" do
    it "returns quotient and remainder with Ruby floor semantics" do
      q, r = ri(7_i64).divmod(ri(3_i64))
      q.to_i64.should eq 2_i64
      r.to_i64.should eq 1_i64
    end

    it "handles negative dividend: -7 divmod 3 => [-3, 2]" do
      q, r = ri(-7_i64).divmod(ri(3_i64))
      q.to_i64.should eq -3_i64
      r.to_i64.should eq 2_i64
    end

    it "handles negative divisor: 7 divmod -3 => [-3, -2]" do
      q, r = ri(7_i64).divmod(ri(-3_i64))
      q.to_i64.should eq -3_i64
      r.to_i64.should eq -2_i64
    end

    it "handles both negative: -7 divmod -3 => [2, -1]" do
      q, r = ri(-7_i64).divmod(ri(-3_i64))
      q.to_i64.should eq 2_i64
      r.to_i64.should eq -1_i64
    end
  end

  describe "#gcd" do
    it "gcd(12, 8) => 4" do
      ri(12_i64).gcd(ri(8_i64)).to_i64.should eq 4_i64
    end

    it "gcd(0, 5) => 5" do
      ri(0_i64).gcd(ri(5_i64)).to_i64.should eq 5_i64
    end

    it "gcd(5, 0) => 5" do
      ri(5_i64).gcd(ri(0_i64)).to_i64.should eq 5_i64
    end

    it "gcd works with negative numbers" do
      ri(-12_i64).gcd(ri(8_i64)).to_i64.should eq 4_i64
    end

    it "gcd(7, 3) => 1 (co-prime)" do
      ri(7_i64).gcd(ri(3_i64)).to_i64.should eq 1_i64
    end
  end

  describe "#lcm" do
    it "lcm(4, 6) => 12" do
      ri(4_i64).lcm(ri(6_i64)).to_i64.should eq 12_i64
    end

    it "lcm(0, 5) => 0" do
      ri(0_i64).lcm(ri(5_i64)).to_i64.should eq 0_i64
    end

    it "lcm(3, 7) => 21" do
      ri(3_i64).lcm(ri(7_i64)).to_i64.should eq 21_i64
    end
  end

  describe "#digits" do
    it "255 in base 16 => [15, 15] (least significant first)" do
      base16 = RubyInteger.new(16_i64)
      result = ri(255_i64).digits(base16)
      result.map(&.to_i64).should eq [15_i64, 15_i64]
    end

    it "0.digits => [0]" do
      base10 = RubyInteger.new(10_i64)
      result = ri(0_i64).digits(base10)
      result.map(&.to_i64).should eq [0_i64]
    end

    it "1234 in base 10 => [4, 3, 2, 1]" do
      base10 = RubyInteger.new(10_i64)
      result = ri(1234_i64).digits(base10)
      result.map(&.to_i64).should eq [4_i64, 3_i64, 2_i64, 1_i64]
    end

    it "8 in base 2 => [0, 0, 0, 1]" do
      base2 = RubyInteger.new(2_i64)
      result = ri(8_i64).digits(base2)
      result.map(&.to_i64).should eq [0_i64, 0_i64, 0_i64, 1_i64]
    end

    it "negative number uses abs value" do
      base10 = RubyInteger.new(10_i64)
      result = ri(-123_i64).digits(base10)
      result.map(&.to_i64).should eq [3_i64, 2_i64, 1_i64]
    end

    it "raises ArgumentError for base < 2" do
      base1 = RubyInteger.new(1_i64)
      expect_raises(ArgumentError) { ri(5_i64).digits(base1) }
    end
  end

  describe "#pow" do
    it "pow(2, 10) => 1024" do
      ri(2_i64).pow(ri(10_i64)).to_i64.should eq 1024_i64
    end

    it "pow with modulus: 2^10 mod 100 => 24" do
      ri(2_i64).pow(ri(10_i64), ri(100_i64)).to_i64.should eq 24_i64
    end

    it "pow with modulus: large base" do
      # 3^200 mod 13
      result = ri(3_i64).pow(ri(200_i64), ri(13_i64))
      # Verify independently: 3^200 mod 13
      expected = BigInt.new(3) ** 200 % 13
      result.to_big.should eq expected
    end

    it "pow without modulus is same as **" do
      ri(5_i64).pow(ri(4_i64)).to_i64.should eq 625_i64
    end

    it "raises ArgumentError for negative exponent with modulus" do
      expect_raises(ArgumentError) { ri(2_i64).pow(ri(-1_i64), ri(7_i64)) }
    end
  end

  describe "#bit_length" do
    it "bit_length of 0 is 0" do
      ri(0_i64).bit_length.should eq 0
    end

    it "bit_length of 1 is 1" do
      ri(1_i64).bit_length.should eq 1
    end

    it "bit_length of 255 is 8" do
      ri(255_i64).bit_length.should eq 8
    end

    it "bit_length of 256 is 9" do
      ri(256_i64).bit_length.should eq 9
    end

    it "bit_length of negative uses abs" do
      ri(-255_i64).bit_length.should eq 8
    end

    it "bit_length of a large BigInt" do
      # 2^100 has bit_length 101
      big = RubyInteger.new(BigInt.new(2) ** 100)
      big.bit_length.should eq 101
    end
  end

  # -----------------------------------------------------------------------
  # Overflow promotion integration test
  # -----------------------------------------------------------------------

  describe "overflow promotion" do
    it "Int64::MAX + 1 promotes to BigInt" do
      max = RubyInteger.new(Int64::MAX)
      result = max + RubyInteger.new(1_i64)
      result.small?.should be_false
      result.to_big.should eq BigInt.new(Int64::MAX) + 1
    end

    it "Int64::MIN - 1 promotes to BigInt" do
      min = RubyInteger.new(Int64::MIN)
      result = min - RubyInteger.new(1_i64)
      result.small?.should be_false
    end

    it "large multiplication promotes to BigInt" do
      a = RubyInteger.new(Int64::MAX)
      result = a * RubyInteger.new(2_i64)
      result.small?.should be_false
    end

    it "BigInt result normalises back to Int64 when it fits" do
      big = RubyInteger.new(BigInt.new(Int64::MAX) + 1)
      small_result = big - RubyInteger.new(2_i64)
      small_result.small?.should be_true
      small_result.to_i64.should eq Int64::MAX - 1
    end
  end

  # -----------------------------------------------------------------------
  # Ruby division/modulo semantics stress test
  # -----------------------------------------------------------------------

  describe "Ruby floor-division stress" do
    # Table: {a, b, expected_q, expected_r}
    [
      {7_i64, 3_i64, 2_i64, 1_i64},
      {-7_i64, 3_i64, -3_i64, 2_i64},
      {7_i64, -3_i64, -3_i64, -2_i64},
      {-7_i64, -3_i64, 2_i64, -1_i64},
      {6_i64, 3_i64, 2_i64, 0_i64},
      {-6_i64, 3_i64, -2_i64, 0_i64},
    ].each do |(a, b, eq, er)|
      it "#{a} / #{b} = #{eq}, #{a} % #{b} = #{er}" do
        ra = ri(a)
        rb = ri(b)
        (ra / rb).to_i64.should eq eq
        (ra % rb).to_i64.should eq er
      end
    end
  end
end
