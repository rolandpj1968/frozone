require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::Context do
  let(:object_class) { Frozone::Vm::Core::OBJECT_CLASS }
  let(:top_level_object) { Frozone::Vm::ObjectObject.new(object_class) }
  let(:frame) { Frozone::Vm::Frame.new(top_level_object, [], [object_class]) }

  describe '#push_frame / #pop_frame / #frame' do
    it 'returns nil when no frames have been pushed' do
      context = described_class.new
      expect(context.frame).to be_nil
    end

    it 'returns the most recently pushed frame' do
      context = described_class.new
      context.push_frame(frame)
      expect(context.frame).to equal(frame)
    end

    it 'pops and returns the last frame' do
      context = described_class.new
      context.push_frame(frame)
      popped = context.pop_frame
      expect(popped).to equal(frame)
      expect(context.frame).to be_nil
    end

    it 'maintains frame stack order' do
      context = described_class.new
      frame2 = Frozone::Vm::Frame.new(top_level_object, [], [object_class])
      context.push_frame(frame)
      context.push_frame(frame2)
      expect(context.frame).to equal(frame2)
      context.pop_frame
      expect(context.frame).to equal(frame)
    end

    it 'raises if pushed object is not a Frame' do
      context = described_class.new
      expect { context.push_frame("not a frame") }.to raise_error(RuntimeError)
    end
  end

  describe '#push_scope / #pop_scope / #scopes' do
    it 'starts with empty scopes' do
      context = described_class.new
      expect(context.scopes).to be_empty
    end

    it 'accumulates pushed scopes' do
      context = described_class.new
      context.push_scope(object_class)
      expect(context.scopes).to eq([object_class])
    end

    it 'pops the last scope' do
      context = described_class.new
      context.push_scope(object_class)
      context.pop_scope
      expect(context.scopes).to be_empty
    end

    it 'raises if scope is not a ClassObject or ModuleObject' do
      context = described_class.new
      expect { context.push_scope("not a scope") }.to raise_error(RuntimeError)
    end
  end
end
