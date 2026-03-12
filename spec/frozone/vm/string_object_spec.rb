require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::StringObject do
  describe '#initialize' do
    it 'accepts a String value' do
      expect { described_class.new("hello") }.not_to raise_error
    end

    it 'accepts an empty string' do
      expect { described_class.new("") }.not_to raise_error
    end

    it 'raises when given a non-String' do
      expect { described_class.new(42)   }.to raise_error(RuntimeError, /String/)
      expect { described_class.new(:sym) }.to raise_error(RuntimeError, /String/)
      expect { described_class.new(nil)  }.to raise_error(RuntimeError, /String/)
    end
  end

  describe '#raw' do
    it 'returns the underlying string value' do
      expect(described_class.new("hello").raw).to eq("hello")
    end

    it 'returns a mutable (unfrozen) string' do
      expect(described_class.new("mutable").raw).not_to be_frozen
    end
  end

  describe '#to_s' do
    it 'returns the string value directly' do
      expect(described_class.new("world").to_s).to eq("world")
    end

    it 'returns an empty string for empty input' do
      expect(described_class.new("").to_s).to eq("")
    end
  end

  describe '#hash and #eql?' do
    it 'is not eql? to a StringObject with a different value' do
      expect(described_class.new("abc").eql?(described_class.new("def"))).to be false
    end

    it 'is not eql? to a plain Ruby String' do
      expect(described_class.new("abc").eql?("abc")).to be false
    end
  end

  describe '#truthy?' do
    it 'is truthy even for an empty string' do
      expect(described_class.new("").truthy?).to be true
    end

    it 'is truthy for a non-empty string' do
      expect(described_class.new("hello").truthy?).to be true
    end
  end
end
