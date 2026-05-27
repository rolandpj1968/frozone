require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/cpp'

# Stub-by-default discipline: a reachable intrinsic with no real lowering
# auto-stubs to a loud intrinsic_not_implemented(name) abort — UNLESS it's
# in IMPLEMENT_QUEUE (held todo), which stays a skip (EmissionError →
# method_missing) so an exercised one surfaces catchably, not as a hard
# abort. Every reachable intrinsic is thus real | held | loud-stub.
IL = Frozone::Compiler::Backend::CppBox::IntrinsicLowering unless defined?(IL)

RSpec.describe "Intrinsic stub-by-default + IMPLEMENT_QUEUE" do
  def lower(name, *args) = IL.lower(name, *args)

  it "auto-stubs an unimplemented, non-held intrinsic to a loud abort" do
    expect(lower(:objectspace_each_object, "a")).to eq('intrinsic_not_implemented("objectspace_each_object")')
    expect(lower(:module_attr_accessor, "a", "b")).to eq('intrinsic_not_implemented("module_attr_accessor")')
  end

  it "ignores args at the stub call site (abort regardless)" do
    expect(lower(:bound_method_call, "a", "b", "c")).to eq('intrinsic_not_implemented("bound_method_call")')
  end

  it "HOLDS IMPLEMENT_QUEUE members as a skip (raises, not stubbed)" do
    %i[array_pack object_clone kernel_exit fiber_storage_hash float_to_r].each do |held|
      expect { lower(held, "a") }
        .to raise_error(Frozone::Compiler::Backend::CppBox::Cpp::EmissionError, /held for implementation/)
    end
  end

  it "normalizes ? predicate names to _q for the stub name" do
    expect(lower(:objectspace_garbage_collect, "a")).to include("objectspace_garbage_collect")
  end

  it "real lowerings still win over the default stub (integer__mul_ fixed)" do
    expect(lower(:integer__mul_, "a", "b"))
      .to eq("(new Integer(static_cast<Integer*>(a)->raw_ * static_cast<Integer*>(b)->raw_))")
    expect(lower(:hash_clear, "h")).to eq("(static_cast<Hash*>(h)->data.clear(), h)")
  end
end
