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

  describe '#hash and #eql?' do
    it 'is not eql? to an ArrayObject with different elements' do
      expect(described_class.new([i1]).eql?(described_class.new([i2]))).to be false
    end

    it 'is not eql? to a plain Ruby Array' do
      expect(described_class.new([]).eql?([])).to be false
    end
  end

  describe '#truthy?' do
    it 'is truthy even when empty' do
      expect(described_class.new([]).truthy?).to be true
    end
  end
end
