require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/cpp'

# Fast (no-build) checks that the Float intrinsic coverage drive lowers
# each gap intrinsic to the expected C++ expression. Receiver/args are
# passed as already-lowered expression strings, per IntrinsicLowering.lower.
IL = Frozone::Compiler::Backend::CppBox::IntrinsicLowering unless defined?(IL)

RSpec.describe "Float intrinsic lowering" do
  def lower(name, *args) = IL.lower(name, *args)

  describe "arithmetic operators (dynamic-dispatch fallback bodies)" do
    it "lowers float__plus_ to an unboxed double add, reboxed" do
      expect(lower(:float__plus_, "a", "b"))
        .to eq("(new Float(static_cast<Float*>(a)->raw_ + static_cast<Float*>(b)->raw_))")
    end

    it "lowers float__pow_ via std::pow" do
      expect(lower(:float__pow_, "a", "b")).to include("std::pow(static_cast<Float*>(a)->raw_, static_cast<Float*>(b)->raw_)")
    end
  end

  describe "comparisons box to bool" do
    it "lowers float__lt_ via boxed_bool" do
      expect(lower(:float__lt_, "a", "b")).to eq("boxed_bool(static_cast<Float*>(a)->raw_ <  static_cast<Float*>(b)->raw_)")
    end
    it "lowers float_eq via boxed_bool ==" do
      expect(lower(:float_eq, "a", "b")).to include("==")
      expect(lower(:float_eq, "a", "b")).to start_with("boxed_bool(")
    end
  end

  describe "constants take no args" do
    it "lowers float_infinity" do
      expect(lower(:float_infinity)).to eq("(new Float(std::numeric_limits<double>::infinity()))")
    end
    it "lowers float_nan" do
      expect(lower(:float_nan)).to include("quiet_NaN()")
    end
  end

  describe "unary <cmath> functions (generated)" do
    {
      float_sqrt: "std::sqrt", float_sin: "std::sin", float_log10: "std::log10",
      float_atanh: "std::atanh", float_erfc: "std::erfc", float_expm1: "std::expm1",
    }.each do |name, fn|
      it "lowers #{name} via #{fn}" do
        expect(lower(name, "x")).to eq("(new Float(#{fn}(static_cast<Float*>(x)->raw_)))")
      end
    end
  end

  describe "binary specials" do
    it "lowers float_hypot via std::hypot" do
      expect(lower(:float_hypot, "a", "b")).to include("std::hypot(")
    end
    it "lowers float_ldexp with an int second arg" do
      expect(lower(:float_ldexp, "a", "n")).to include("std::ldexp(static_cast<Float*>(a)->raw_, static_cast<int>(static_cast<Integer*>(n)->raw_))")
    end
    it "lowers float_next_float via nextafter toward +inf" do
      expect(lower(:float_next_float, "x")).to include("std::nextafter(static_cast<Float*>(x)->raw_, std::numeric_limits<double>::infinity())")
    end
  end

  describe "Phase 2 round-family + multi-return → hpp functions" do
    it "lowers float_round to the hpp fn with self/ndigits/half" do
      expect(lower(:float_round, "s", "n", "h")).to eq("intrinsic_float_round(s, n, h)")
    end
    it "lowers float_ceil / float_floor / float_truncate with ndigits" do
      expect(lower(:float_ceil, "s", "n")).to eq("intrinsic_float_ceil(s, n)")
      expect(lower(:float_floor, "s", "n")).to eq("intrinsic_float_floor(s, n)")
      expect(lower(:float_truncate, "s", "n")).to eq("intrinsic_float_truncate(s, n)")
    end
    it "lowers float_frexp / float_lgamma (multi-value returns)" do
      expect(lower(:float_frexp, "s")).to eq("intrinsic_float_frexp(s)")
      expect(lower(:float_lgamma, "s")).to eq("intrinsic_float_lgamma(s)")
    end
  end

  describe "auto-stubs for not-yet-implemented intrinsics" do
    it "float_to_r emits a not_implemented stub" do
      expect(lower(:float_to_r, "x")).to eq('intrinsic_not_implemented("float_to_r")')
    end
  end

  describe "now-lowered (Phase 2 / Tier 3 graduations)" do
    it "float_rationalize is pure Ruby now, the intrinsic auto-stubs" do
      expect(lower(:float_rationalize, "x")).to eq('intrinsic_not_implemented("float_rationalize")')
    end
    it "float_gamma lowers via HPP_INTRINSICS" do
      expect(lower(:float_gamma, "x")).to eq("intrinsic_float_gamma(x)")
    end
  end
end
