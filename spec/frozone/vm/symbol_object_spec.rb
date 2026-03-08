require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::SymbolObject do
  describe '.from' do
    it 'returns a SymbolObject' do
      expect(described_class.from(:foo)).to be_a(described_class)
    end

    it 'returns the same object for the same symbol (interned)' do
      expect(described_class.from(:foo)).to equal(described_class.from(:foo))
    end

    it 'returns different objects for different symbols' do
      expect(described_class.from(:foo)).not_to equal(described_class.from(:bar))
    end

    it 'raises when given a non-Symbol' do
      expect { described_class.from("not_a_symbol") }.to raise_error(RuntimeError, /Symbol/)
      expect { described_class.from(42) }.to raise_error(RuntimeError, /Symbol/)
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new(:foo) }.to raise_error(NoMethodError)
    end
  end

  describe '#raw' do
    it 'returns the underlying Ruby Symbol' do
      expect(described_class.from(:hello).raw).to eq(:hello)
    end
  end

  describe '#to_s' do
    it 'returns ":name"' do
      expect(described_class.from(:foo).to_s).to eq(":foo")
    end
  end

  describe '#truthy?' do
    it 'is truthy' do
      expect(described_class.from(:anything).truthy?).to be true
    end
  end
end
