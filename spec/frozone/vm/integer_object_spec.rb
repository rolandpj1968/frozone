require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::IntegerObject do
  describe '#initialize' do
    it 'accepts an integer value' do
      expect { described_class.new(42) }.not_to raise_error
    end

    it 'raises when given a non-integer' do
      expect { described_class.new("42") }.to raise_error(RuntimeError, /Integer/)
      expect { described_class.new(3.14) }.to raise_error(RuntimeError, /Integer/)
      expect { described_class.new(nil) }.to raise_error(RuntimeError, /Integer/)
    end
  end

  describe '#raw' do
    it 'returns the underlying integer value' do
      expect(described_class.new(99).raw).to eq(99)
      expect(described_class.new(-7).raw).to eq(-7)
      expect(described_class.new(0).raw).to eq(0)
    end
  end

  describe '#eql?' do
    it 'returns false for two IntegerObjects with different values' do
      expect(described_class.new(5).eql?(described_class.new(6))).to be false
    end

    it 'returns false when compared to a non-IntegerObject' do
      expect(described_class.new(5).eql?(5)).to be false
    end
  end

  describe '#truthy?' do
    it 'is truthy' do
      expect(described_class.new(0).truthy?).to be true
      expect(described_class.new(1).truthy?).to be true
    end
  end
end
