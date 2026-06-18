require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::HashObject do
  let(:k) { Frozone::Vm::SymbolObject.from(:key) }
  let(:v) { Frozone::Vm::IntegerObject.new(42) }

  describe '#initialize' do
    it 'accepts a Hash' do
      expect { described_class.new({}) }.not_to raise_error
    end

    it 'raises when given a non-Hash' do
      expect { described_class.new([]) }.to raise_error(RuntimeError, /Hash/)
      expect { described_class.new(nil) }.to raise_error(RuntimeError, /Hash/)
    end
  end

  describe '#raw' do
    it 'returns a Hash with the original VM-object keys' do
      h = { k => v }
      obj = described_class.new(h)
      expect(obj.raw[k]).to equal(v)
    end
  end

  describe '#hash and #eql?' do
    it 'is not eql? to a HashObject with different contents' do
      other_v = Frozone::Vm::IntegerObject.new(99)
      expect(described_class.new({ k => v }).eql?(described_class.new({ k => other_v }))).to be false
    end

    it 'is not eql? to a plain Ruby Hash' do
      expect(described_class.new({}).eql?({})).to be false
    end
  end

  describe '#truthy?' do
    it 'is truthy even when empty' do
      expect(described_class.new({}).truthy?).to be true
    end
  end
end
