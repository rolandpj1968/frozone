require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::Frame do
  let(:top_level_object) { Frozone::Vm::ObjectObject.new(Frozone::Vm::Core::OBJECT_CLASS) }
  let(:scope) { Frozone::Vm::Core::OBJECT_CLASS }

  describe '#initialize' do
    it 'initializes declared locals to NilObject::NIL' do
      frame = described_class.new(top_level_object, [:x, :y], [scope])
      expect(frame.get_local(:x)).to equal(Frozone::Vm::NilObject::NIL)
      expect(frame.get_local(:y)).to equal(Frozone::Vm::NilObject::NIL)
    end

    it 'returns nil for undeclared locals' do
      frame = described_class.new(top_level_object, [], [scope])
      expect(frame.get_local(:z)).to be_nil
    end
  end

  describe '#the_self' do
    it 'returns the receiver object' do
      frame = described_class.new(top_level_object, [], [scope])
      expect(frame.the_self).to equal(top_level_object)
    end
  end

  describe '#set_local / #get_local' do
    it 'stores and retrieves a local variable' do
      frame = described_class.new(top_level_object, [:n], [scope])
      val = Frozone::Vm::IntegerObject.new(42)
      frame.set_local(:n, val)
      expect(frame.get_local(:n)).to equal(val)
    end

    it 'can set an undeclared local' do
      frame = described_class.new(top_level_object, [], [scope])
      val = Frozone::Vm::IntegerObject.new(1)
      frame.set_local(:dynamic, val)
      expect(frame.get_local(:dynamic)).to equal(val)
    end

    it 'overwrites a previously set value' do
      frame = described_class.new(top_level_object, [:x], [scope])
      frame.set_local(:x, Frozone::Vm::IntegerObject.new(1))
      frame.set_local(:x, Frozone::Vm::IntegerObject.new(2))
      expect(frame.get_local(:x).raw).to eq(2)
    end
  end

  describe '#scopes' do
    it 'returns the scopes passed at construction' do
      frame = described_class.new(top_level_object, [], [scope])
      expect(frame.scopes).to eq([scope])
    end
  end
end
