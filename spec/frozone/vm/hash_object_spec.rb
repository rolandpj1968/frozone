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
    it 'returns the underlying Hash' do
      h = { k => v }
      expect(described_class.new(h).raw).to equal(h)
    end
  end

  describe '#to_s' do
    it 'returns "{}" for an empty hash' do
      expect(described_class.new({}).to_s).to eq("{}")
    end

    it 'includes key and value representations' do
      obj = described_class.new({ k => v })
      expect(obj.to_s).to include(":key")
      expect(obj.to_s).to include("42")
    end
  end

  describe '#hash and #eql?' do
    it 'is eql? to another HashObject with the same contents' do
      h1 = described_class.new({ k => v })
      h2 = described_class.new({ k => v })
      expect(h1.eql?(h2)).to be true
    end

    it 'is not eql? to a HashObject with different contents' do
      other_v = Frozone::Vm::IntegerObject.new(99)
      expect(described_class.new({ k => v }).eql?(described_class.new({ k => other_v }))).to be false
    end

    it 'is not eql? to a plain Ruby Hash' do
      expect(described_class.new({}).eql?({})).to be false
    end

    it 'equal hashes have equal hashes' do
      expect(described_class.new({ k => v }).hash).to eq(described_class.new({ k => v }).hash)
    end
  end

  describe '#truthy?' do
    it 'is truthy even when empty' do
      expect(described_class.new({}).truthy?).to be true
    end
  end
end
