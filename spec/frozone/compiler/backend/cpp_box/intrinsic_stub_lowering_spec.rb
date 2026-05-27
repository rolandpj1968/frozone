require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/cpp'

# The loud-stub mechanism: reachable-but-deliberately-unimplemented
# intrinsics (STUB_INTRINSICS) lower to intrinsic_not_implemented(name)
# — a definite, tracked state — while genuinely unclassified names still
# raise (the forcing function to classify every reachable intrinsic).
IL = Frozone::Compiler::Backend::CppBox::IntrinsicLowering unless defined?(IL)

RSpec.describe "Intrinsic loud-stub mechanism" do
  def lower(name, *args) = IL.lower(name, *args)

  it "lowers a STUB_INTRINSICS member to a loud abort with its name" do
    expect(lower(:objectspace_each_object, "a")).to eq('intrinsic_not_implemented("objectspace_each_object")')
  end

  it "ignores args at the stub call site (abort regardless)" do
    expect(lower(:bound_method_call, "a", "b", "c")).to eq('intrinsic_not_implemented("bound_method_call")')
  end

  it "still RAISES for an unclassified reachable intrinsic (forcing function)" do
    expect { lower(:module_attr_accessor, "a") }
      .to raise_error(Frozone::Compiler::Backend::CppBox::Cpp::EmissionError, /classify/)
  end

  it "fixed integer__mul_ (was misnamed integer__star_) lowers to real multiply" do
    expect(lower(:integer__mul_, "a", "b"))
      .to eq("(new Integer(static_cast<Integer*>(a)->raw_ * static_cast<Integer*>(b)->raw_))")
  end

  it "integer__star_ (dead name) now raises — renamed away" do
    expect { lower(:integer__star_, "a", "b") }
      .to raise_error(Frozone::Compiler::Backend::CppBox::Cpp::EmissionError)
  end
end
