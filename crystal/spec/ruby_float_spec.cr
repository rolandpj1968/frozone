require "spec"
require "../src/ruby_float"

# Convenience helpers
private def rf(v : Float64) : RubyFloat
  RubyFloat.new(v)
end

private def ri(v : Int64) : RubyInteger
  RubyInteger.new(v)
end

describe RubyFloat do
  # -----------------------------------------------------------------------
  # Construction
  # -----------------------------------------------------------------------

  describe ".new" do
    it "creates a RubyFloat from Float64" do
      rf(3.14).to_f.should eq 3.14
    end

    it "creates a RubyFloat from Int64" do
      RubyFloat.new(42_i64).to_f.should eq 42.0
    end

    it "wraps positive infinity" do
      rf(Float64::INFINITY).infinite?.should eq 1
    end

    it "wraps negative infinity" do
      rf(-Float64::INFINITY).infinite?.should eq -1
    end

    it "wraps NaN" do
      rf(Float64::NAN).nan?.should be_true
    end
  end

  # -----------------------------------------------------------------------
  # Constants
  # -----------------------------------------------------------------------

  describe "constants" do
    it "INFINITY is positive infinity" do
      RubyFloat::INFINITY.infinite?.should eq 1
    end

    it "NAN is not-a-number" do
      RubyFloat::NAN.nan?.should be_true
    end

    it "EPSILON is Float64::EPSILON" do
      RubyFloat::EPSILON.to_f.should eq Float64::EPSILON
    end

    it "MAX is Float64::MAX" do
      RubyFloat::MAX.to_f.should eq Float64::MAX
    end

    it "MIN is Float64::MIN_POSITIVE" do
      RubyFloat::MIN.to_f.should eq Float64::MIN_POSITIVE
    end

    it "DIG is 15" do
      RubyFloat::DIG.should eq 15
    end

    it "MANT_DIG is 53" do
      RubyFloat::MANT_DIG.should eq 53
    end
  end

  # -----------------------------------------------------------------------
  # Arithmetic — Float op Float
  # -----------------------------------------------------------------------

  describe "#+" do
    it "adds two floats" do
      (rf(1.5) + rf(2.5)).to_f.should eq 4.0
    end

    it "adds with negative" do
      (rf(-3.0) + rf(1.0)).to_f.should eq -2.0
    end
  end

  describe "#-" do
    it "subtracts two floats" do
      (rf(5.0) - rf(2.0)).to_f.should eq 3.0
    end

    it "subtracts to negative" do
      (rf(1.0) - rf(3.0)).to_f.should eq -2.0
    end
  end

  describe "#*" do
    it "multiplies two floats" do
      (rf(3.0) * rf(4.0)).to_f.should eq 12.0
    end

    it "multiplies with zero" do
      (rf(99.0) * rf(0.0)).to_f.should eq 0.0
    end
  end

  describe "#/" do
    it "divides two floats" do
      (rf(10.0) / rf(4.0)).to_f.should eq 2.5
    end

    it "1.0 / 0.0 => Infinity" do
      (rf(1.0) / rf(0.0)).infinite?.should eq 1
    end

    it "-1.0 / 0.0 => -Infinity" do
      (rf(-1.0) / rf(0.0)).infinite?.should eq -1
    end

    it "0.0 / 0.0 => NaN" do
      (rf(0.0) / rf(0.0)).nan?.should be_true
    end
  end

  describe "#%" do
    it "positive % positive" do
      (rf(10.0) % rf(3.0)).to_f.should eq 1.0
    end

    it "-7.0 % 3.0 => 2.0 (sign of divisor)" do
      (rf(-7.0) % rf(3.0)).to_f.should eq 2.0
    end

    it "7.0 % -3.0 => -2.0 (sign of divisor)" do
      (rf(7.0) % rf(-3.0)).to_f.should eq -2.0
    end

    it "exact division yields 0.0" do
      (rf(6.0) % rf(2.0)).to_f.should eq 0.0
    end

    it "% by zero => NaN" do
      (rf(1.0) % rf(0.0)).nan?.should be_true
    end
  end

  describe "#**" do
    it "raises to a float power" do
      (rf(2.0) ** rf(10.0)).to_f.should eq 1024.0
    end

    it "fractional exponent" do
      (rf(4.0) ** rf(0.5)).to_f.should be_close(2.0, 1e-10)
    end
  end

  # -----------------------------------------------------------------------
  # Arithmetic — Float op Integer
  # -----------------------------------------------------------------------

  describe "Float op Integer" do
    it "adds integer" do
      (rf(1.5) + ri(2_i64)).to_f.should eq 3.5
    end

    it "subtracts integer" do
      (rf(5.0) - ri(2_i64)).to_f.should eq 3.0
    end

    it "multiplies integer" do
      (rf(2.5) * ri(4_i64)).to_f.should eq 10.0
    end

    it "divides by integer" do
      (rf(7.0) / ri(2_i64)).to_f.should eq 3.5
    end

    it "modulo with integer: -7.0 % 3 => 2.0" do
      (rf(-7.0) % ri(3_i64)).to_f.should eq 2.0
    end

    it "power with integer" do
      (rf(2.0) ** ri(8_i64)).to_f.should eq 256.0
    end
  end

  # -----------------------------------------------------------------------
  # Unary operators
  # -----------------------------------------------------------------------

  describe "#-@" do
    it "negates a positive float" do
      (-rf(3.5)).to_f.should eq -3.5
    end

    it "negates a negative float" do
      (-rf(-3.5)).to_f.should eq 3.5
    end

    it "-(-0.0) gives 0.0" do
      result = -rf(-0.0)
      result.to_f.should eq 0.0
    end
  end

  describe "#abs" do
    it "abs of positive" do
      rf(3.5).abs.to_f.should eq 3.5
    end

    it "abs of negative" do
      rf(-3.5).abs.to_f.should eq 3.5
    end

    it "abs of zero" do
      rf(0.0).abs.to_f.should eq 0.0
    end
  end

  # -----------------------------------------------------------------------
  # Integer division
  # -----------------------------------------------------------------------

  describe "#idiv" do
    it "7.0.idiv(2.0) => 3 (floor)" do
      rf(7.0).idiv(rf(2.0)).to_i64.should eq 3_i64
    end

    it "-7.0.idiv(2.0) => -4 (floor toward -∞)" do
      rf(-7.0).idiv(rf(2.0)).to_i64.should eq -4_i64
    end

    it "7.0.idiv(-2.0) => -4" do
      rf(7.0).idiv(rf(-2.0)).to_i64.should eq -4_i64
    end

    it "returns RubyInteger" do
      result = rf(5.0).idiv(rf(2.0))
      result.should be_a(RubyInteger)
    end

    it "raises DivisionByZeroError for zero divisor" do
      expect_raises(DivisionByZeroError) { rf(1.0).idiv(rf(0.0)) }
    end

    it "idiv with RubyInteger arg" do
      rf(7.0).idiv(ri(2_i64)).to_i64.should eq 3_i64
    end
  end

  # -----------------------------------------------------------------------
  # divmod
  # -----------------------------------------------------------------------

  describe "#divmod" do
    it "7.0.divmod(3.0) => [2, 1.0]" do
      q, r = rf(7.0).divmod(rf(3.0))
      q.to_i64.should eq 2_i64
      r.to_f.should eq 1.0
    end

    it "-7.0.divmod(3.0) => [-3, 2.0]" do
      q, r = rf(-7.0).divmod(rf(3.0))
      q.to_i64.should eq -3_i64
      r.to_f.should eq 2.0
    end

    it "7.0.divmod(-3.0) => [-3, -2.0]" do
      q, r = rf(7.0).divmod(rf(-3.0))
      q.to_i64.should eq -3_i64
      r.to_f.should eq -2.0
    end

    it "divmod with RubyInteger arg" do
      q, r = rf(7.0).divmod(ri(3_i64))
      q.to_i64.should eq 2_i64
      r.to_f.should eq 1.0
    end
  end

  # -----------------------------------------------------------------------
  # Comparison
  # -----------------------------------------------------------------------

  describe "#<=>" do
    it "returns 0 for equal values" do
      (rf(3.0) <=> rf(3.0)).should eq 0
    end

    it "returns negative when less" do
      result = rf(1.0) <=> rf(2.0)
      result.should_not be_nil
      result.not_nil!.should be < 0
    end

    it "returns positive when greater" do
      result = rf(3.0) <=> rf(2.0)
      result.should_not be_nil
      result.not_nil!.should be > 0
    end

    it "returns nil for NaN on left" do
      result = RubyFloat::NAN <=> rf(1.0)
      result.should be_nil
    end

    it "returns nil for NaN on right" do
      result = rf(1.0) <=> RubyFloat::NAN
      result.should be_nil
    end
  end

  describe "#==" do
    it "equal floats" do
      (rf(1.5) == rf(1.5)).should be_true
    end

    it "unequal floats" do
      (rf(1.5) == rf(2.5)).should be_false
    end

    it "NaN != NaN" do
      (RubyFloat::NAN == RubyFloat::NAN).should be_false
    end

    it "float == integer" do
      (rf(2.0) == ri(2_i64)).should be_true
    end
  end

  describe "#< #<= #> #>=" do
    it "< is correct" do
      (rf(1.0) < rf(2.0)).should be_true
      (rf(2.0) < rf(1.0)).should be_false
    end

    it "<= is correct" do
      (rf(2.0) <= rf(2.0)).should be_true
      (rf(1.0) <= rf(2.0)).should be_true
      (rf(3.0) <= rf(2.0)).should be_false
    end

    it "> is correct" do
      (rf(2.0) > rf(1.0)).should be_true
      (rf(1.0) > rf(2.0)).should be_false
    end

    it ">= is correct" do
      (rf(2.0) >= rf(2.0)).should be_true
      (rf(3.0) >= rf(2.0)).should be_true
      (rf(1.0) >= rf(2.0)).should be_false
    end

    it "NaN comparisons are always false" do
      nan = RubyFloat::NAN
      (nan < rf(1.0)).should be_false
      (nan > rf(1.0)).should be_false
      (nan <= rf(1.0)).should be_false
      (nan >= rf(1.0)).should be_false
    end
  end

  # -----------------------------------------------------------------------
  # Rounding
  # -----------------------------------------------------------------------

  describe "#floor" do
    it "floor(3.7) => 3 as RubyInteger" do
      result = rf(3.7).floor
      result.should be_a(RubyInteger)
      result.as(RubyInteger).to_i64.should eq 3_i64
    end

    it "floor(-3.2) => -4 as RubyInteger" do
      rf(-3.2).floor.as(RubyInteger).to_i64.should eq -4_i64
    end

    it "floor(1.234, 2) => 1.23 as RubyFloat" do
      result = rf(1.234).floor(2)
      result.should be_a(RubyFloat)
      result.as(RubyFloat).to_f.should be_close(1.23, 1e-10)
    end
  end

  describe "#ceil" do
    it "ceil(3.2) => 4 as RubyInteger" do
      rf(3.2).ceil.as(RubyInteger).to_i64.should eq 4_i64
    end

    it "ceil(-3.7) => -3 as RubyInteger" do
      rf(-3.7).ceil.as(RubyInteger).to_i64.should eq -3_i64
    end

    it "ceil(1.234, 2) => 1.24 as RubyFloat" do
      result = rf(1.234).ceil(2)
      result.should be_a(RubyFloat)
      result.as(RubyFloat).to_f.should be_close(1.24, 1e-10)
    end
  end

  describe "#round" do
    it "round(3.5) => 4 as RubyInteger" do
      rf(3.5).round.as(RubyInteger).to_i64.should eq 4_i64
    end

    it "round(3.4) => 3 as RubyInteger" do
      rf(3.4).round.as(RubyInteger).to_i64.should eq 3_i64
    end

    it "round(-3.5) => -4 as RubyInteger" do
      rf(-3.5).round.as(RubyInteger).to_i64.should eq -4_i64
    end

    it "round(1.255, 2) returns RubyFloat" do
      result = rf(1.25).round(1)
      result.should be_a(RubyFloat)
    end
  end

  describe "#truncate" do
    it "truncate(3.9) => 3 as RubyInteger" do
      rf(3.9).truncate.as(RubyInteger).to_i64.should eq 3_i64
    end

    it "truncate(-3.9) => -3 as RubyInteger (toward zero)" do
      rf(-3.9).truncate.as(RubyInteger).to_i64.should eq -3_i64
    end

    it "truncate(1.789, 2) => 1.78 as RubyFloat" do
      result = rf(1.789).truncate(2)
      result.should be_a(RubyFloat)
      result.as(RubyFloat).to_f.should be_close(1.78, 1e-10)
    end
  end

  # -----------------------------------------------------------------------
  # Conversion
  # -----------------------------------------------------------------------

  describe "#to_i" do
    it "truncates toward zero for positive" do
      rf(3.9).to_i.to_i64.should eq 3_i64
    end

    it "truncates toward zero for negative" do
      rf(-3.9).to_i.to_i64.should eq -3_i64
    end

    it "returns RubyInteger" do
      rf(5.5).to_i.should be_a(RubyInteger)
    end
  end

  describe "#to_f" do
    it "returns the underlying Float64" do
      rf(3.14).to_f.should eq 3.14
    end

    it "returns a Float64 type" do
      rf(1.0).to_f.should be_a(Float64)
    end
  end

  describe "#to_f64" do
    it "returns the same value as to_f" do
      rf(2.71).to_f64.should eq 2.71
    end

    it "returns a Float64 type" do
      rf(1.0).to_f64.should be_a(Float64)
    end
  end

  describe "#to_s" do
    it "1.0 => '1.0'" do
      rf(1.0).to_s.should eq "1.0"
    end

    it "1.5 => '1.5'" do
      rf(1.5).to_s.should eq "1.5"
    end

    it "NaN => 'NaN'" do
      RubyFloat::NAN.to_s.should eq "NaN"
    end

    it "Infinity => 'Infinity'" do
      RubyFloat::INFINITY.to_s.should eq "Infinity"
    end

    it "-Infinity => '-Infinity'" do
      (-RubyFloat::INFINITY).to_s.should eq "-Infinity"
    end

    it "always contains a decimal point for finite floats" do
      s = rf(100.0).to_s
      (s.includes?('.') || s.includes?('e')).should be_true
    end
  end

  describe "#inspect" do
    it "same as to_s" do
      rf(1.5).inspect.should eq rf(1.5).to_s
      RubyFloat::NAN.inspect.should eq "NaN"
    end
  end

  # -----------------------------------------------------------------------
  # Predicates
  # -----------------------------------------------------------------------

  describe "#nan?" do
    it "is true for NaN" do
      RubyFloat::NAN.nan?.should be_true
    end

    it "is false for normal float" do
      rf(1.0).nan?.should be_false
    end

    it "is false for Infinity" do
      RubyFloat::INFINITY.nan?.should be_false
    end
  end

  describe "#infinite?" do
    it "returns 1 for positive infinity" do
      RubyFloat::INFINITY.infinite?.should eq 1
    end

    it "returns -1 for negative infinity" do
      (-RubyFloat::INFINITY).infinite?.should eq -1
    end

    it "returns 0 for finite float" do
      rf(1.0).infinite?.should eq 0
    end

    it "returns 0 for NaN" do
      RubyFloat::NAN.infinite?.should eq 0
    end
  end

  describe "#finite?" do
    it "is true for normal float" do
      rf(1.0).finite?.should be_true
    end

    it "is false for Infinity" do
      RubyFloat::INFINITY.finite?.should be_false
    end

    it "is false for NaN" do
      RubyFloat::NAN.finite?.should be_false
    end
  end

  describe "#zero?" do
    it "is true for 0.0" do
      rf(0.0).zero?.should be_true
    end

    it "is true for -0.0" do
      rf(-0.0).zero?.should be_true
    end

    it "is false for non-zero" do
      rf(1.0).zero?.should be_false
      rf(-1.0).zero?.should be_false
    end
  end

  describe "#positive?" do
    it "is true for positive float" do
      rf(1.0).positive?.should be_true
    end

    it "is false for zero" do
      rf(0.0).positive?.should be_false
    end

    it "is false for negative" do
      rf(-1.0).positive?.should be_false
    end

    it "is false for NaN" do
      RubyFloat::NAN.positive?.should be_false
    end
  end

  describe "#negative?" do
    it "is true for negative float" do
      rf(-1.0).negative?.should be_true
    end

    it "is false for zero" do
      rf(0.0).negative?.should be_false
    end

    it "is false for positive" do
      rf(1.0).negative?.should be_false
    end

    it "is false for NaN" do
      RubyFloat::NAN.negative?.should be_false
    end
  end

  # -----------------------------------------------------------------------
  # Hash
  # -----------------------------------------------------------------------

  describe "#hash" do
    it "returns a UInt64" do
      rf(1.0).hash.should be_a(UInt64)
    end

    it "equal floats have same hash" do
      rf(3.14).hash.should eq rf(3.14).hash
    end
  end

  # -----------------------------------------------------------------------
  # -0.0 semantics
  # -----------------------------------------------------------------------

  describe "-0.0 semantics" do
    it "-0.0 is zero?" do
      rf(-0.0).zero?.should be_true
    end

    it "-0.0 == 0.0" do
      (rf(-0.0) == rf(0.0)).should be_true
    end

    it "-0.0 is not positive?" do
      rf(-0.0).positive?.should be_false
    end

    it "-0.0 is not negative? (matches Ruby: -0.0.negative? => false)" do
      # Ruby: (-0.0).negative? => false (zero is not negative)
      rf(-0.0).negative?.should be_false
    end
  end

  # -----------------------------------------------------------------------
  # Cross-type wiring: RubyInteger#to_f <-> RubyFloat#to_i
  # -----------------------------------------------------------------------

  describe "cross-type wiring" do
    it "RubyInteger#to_f returns RubyFloat" do
      ri(7_i64).to_f.should be_a(RubyFloat)
    end

    it "RubyInteger#to_f wraps the correct value" do
      ri(7_i64).to_f.to_f.should eq 7.0
    end

    it "RubyInteger#to_f64 returns raw Float64" do
      ri(3_i64).to_f64.should eq 3.0
      ri(3_i64).to_f64.should be_a(Float64)
    end

    it "RubyInteger#to_f and to_f64 agree on value" do
      n = ri(42_i64)
      n.to_f.to_f.should eq n.to_f64
    end

    it "RubyFloat#to_i truncates toward zero (positive)" do
      rf(3.9).to_i.to_i64.should eq 3_i64
    end

    it "RubyFloat#to_i truncates toward zero (negative)" do
      rf(-3.9).to_i.to_i64.should eq -3_i64
    end

    it "RubyFloat#to_i returns RubyInteger" do
      rf(5.5).to_i.should be_a(RubyInteger)
    end

    it "integer -> float -> integer round-trips for whole numbers" do
      ri(100_i64).to_f.to_i.to_i64.should eq 100_i64
    end

    it "float -> integer -> float round-trips for whole-number floats" do
      rf(42.0).to_i.to_f.to_f.should eq 42.0
    end

    it "BigInt integer converts to RubyFloat correctly" do
      big = RubyInteger.new(BigInt.new("1000000000000"))
      f = big.to_f
      f.should be_a(RubyFloat)
      f.to_f.should eq 1_000_000_000_000.0
    end
  end
end
