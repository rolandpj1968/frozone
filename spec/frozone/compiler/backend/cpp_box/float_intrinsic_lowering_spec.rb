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

  describe "deferred (Phase 2) intrinsics still raise" do
    it "float_round is not yet lowered" do
      expect { lower(:float_round, "x") }.to raise_error(Frozone::Compiler::Backend::CppBox::Cpp::EmissionError)
    end
  end
end
