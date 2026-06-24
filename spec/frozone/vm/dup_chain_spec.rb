# Interpreter-mode coverage for the dup-chain primitives consolidated
# in #199. The bench/stubs/dup_test integration covers the user-facing
# Object#dup / Object#clone behavior (which loads core/4.0 Ruby on top
# of these primitives). This spec verifies the host-MRI primitives
# directly: Intrinsics.object_shallow_copy preserves frozen state and
# eigenclass, and the unfreeze + clear_singleton hooks behave.
#
# Together with bench/stubs/dup_test (compiled mode) these cover both
# code paths from a single canonical scenario.

require_relative '../../support/vm_loader'

RSpec.describe 'Vm dup-chain primitives (#199)' do
  let(:source) do
    Frozone::Vm::ObjectObject.new(Frozone::Vm::Core::OBJECT_CLASS).tap do |o|
      o.set_ivar(:@x, Frozone::Vm::IntegerObject.new(1))
    end
  end

  describe 'Intrinsics.object_shallow_copy' do
    it 'returns a fresh instance of the source class' do
      r = Frozone::Vm::Intrinsics.object_shallow_copy(nil, source)
      expect(r).not_to equal(source)
      expect(r.class).to equal(source.class)
      expect(r.class_object).to equal(source.class_object)
    end

    it 'copies ivar slots independently from source (ivars hash is dup\'d)' do
      r = Frozone::Vm::Intrinsics.object_shallow_copy(nil, source)
      r.set_ivar(:@x, Frozone::Vm::IntegerObject.new(99))
      expect(source.get_ivar(:@x).raw).to eq(1)
      expect(r.get_ivar(:@x).raw).to eq(99)
    end

    it 'preserves frozen state from source (caller decides reset)' do
      source.freeze_object!
      r = Frozone::Vm::Intrinsics.object_shallow_copy(nil, source)
      expect(r.frozen_object?).to be(true)
    end
  end

  describe 'Intrinsics.object_unfreeze' do
    it 'clears the frozen flag on a frozen receiver' do
      source.freeze_object!
      Frozone::Vm::Intrinsics.object_unfreeze(nil, source)
      expect(source.frozen_object?).to be(false)
    end
  end

  describe 'Intrinsics.object_clear_singleton' do
    it 'sets @eigenclass to nil' do
      source.__set_eigenclass__(Frozone::Vm::ClassObject.new(:S, nil, Frozone::Vm::Core::OBJECT_CLASS))
      expect(source.eigenclass).not_to be_nil
      Frozone::Vm::Intrinsics.object_clear_singleton(nil, source)
      expect(source.eigenclass).to be_nil
    end
  end
end
