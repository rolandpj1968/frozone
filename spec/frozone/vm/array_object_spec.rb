require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::ArrayObject do
  let(:i1) { Frozone::Vm::IntegerObject.new(1) }
  let(:i2) { Frozone::Vm::IntegerObject.new(2) }

  describe '#initialize' do
    it 'accepts an Array' do
      expect { described_class.new([]) }.not_to raise_error
    end

    it 'raises when given a non-Array' do
      expect { described_class.new("oops") }.to raise_error(RuntimeError, /Array/)
      expect { described_class.new(nil)    }.to raise_error(RuntimeError, /Array/)
    end
  end

  describe '#raw' do
    it 'returns the underlying Array' do
      elements = [i1, i2]
      expect(described_class.new(elements).raw).to equal(elements)
    end
  end

  describe '#to_s' do
    it 'returns "[]" for an empty array' do
      expect(described_class.new([]).to_s).to eq("[]")
    end

    it 'formats elements separated by ", "' do
      expect(described_class.new([i1, i2]).to_s).to eq("[1, 2]")
    end
  end

  describe '#hash and #eql?' do
    it 'is eql? to another ArrayObject with the same elements' do
      a1 = described_class.new([i1])
      a2 = described_class.new([i1])
      expect(a1.eql?(a2)).to be true
    end

    it 'is not eql? to an ArrayObject with different elements' do
      expect(described_class.new([i1]).eql?(described_class.new([i2]))).to be false
    end

    it 'is not eql? to a plain Ruby Array' do
      expect(described_class.new([]).eql?([])).to be false
    end

    it 'equal arrays have equal hashes' do
      expect(described_class.new([i1]).hash).to eq(described_class.new([i1]).hash)
    end
  end

  describe '#truthy?' do
    it 'is truthy even when empty' do
      expect(described_class.new([]).truthy?).to be true
    end
  end
end
