require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/backend/cpp_box/cpp'

# Fast (no-build) checks for the Array mutator coverage drive.
IL = Frozone::Compiler::Backend::CppBox::IntrinsicLowering unless defined?(IL)

RSpec.describe "Array intrinsic lowering" do
  def lower(name, *args) = IL.lower(name, *args)

  describe "Phase 1 mutators (vector ops, arity 1)" do
    it "lowers array_pop to back()+pop_back, nil on empty" do
      out = lower(:array_pop, "a")
      expect(out).to include("static_cast<Array*>(a)")
      expect(out).to include("data.pop_back()")
      expect(out).to include("data.empty()")
    end

    it "lowers array_shift to front()+erase(begin), nil on empty" do
      out = lower(:array_shift, "a")
      expect(out).to include("data.front()")
      expect(out).to include("data.erase(")
      expect(out).to include("data.empty()")
    end
  end

  describe "Phase 2 (RNG / freeze / splat / complex) still deferred" do
    %i[array_sample array_clone array_unshift array_initialize].each do |name|
      it "#{name} is not yet lowered" do
        expect { lower(name, "a") }.to raise_error(Frozone::Compiler::Backend::CppBox::Cpp::EmissionError)
      end
    end
  end
end
