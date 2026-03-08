require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::Intrinsics do
  let(:i3) { Frozone::Vm::IntegerObject.new(3) }
  let(:i5) { Frozone::Vm::IntegerObject.new(5) }
  let(:ctx) { nil } # context is unused by these intrinsics

  describe '.integer__plus_' do
    it 'adds two integers' do
      result = described_class.integer__plus_(ctx, i3, i5)
      expect(result).to be_a(Frozone::Vm::IntegerObject)
      expect(result.raw).to eq(8)
    end

    it 'raises when given non-integer arguments' do
      expect { described_class.integer__plus_(ctx, i3, "not an int") }.to raise_error(RuntimeError)
    end
  end

  describe '.integer__minus_' do
    it 'subtracts two integers' do
      result = described_class.integer__minus_(ctx, i5, i3)
      expect(result).to be_a(Frozone::Vm::IntegerObject)
      expect(result.raw).to eq(2)
    end

    it 'produces negative results' do
      result = described_class.integer__minus_(ctx, i3, i5)
      expect(result.raw).to eq(-2)
    end
  end

  describe '.integer__lt_' do
    it 'returns TRUE when left < right' do
      expect(described_class.integer__lt_(ctx, i3, i5)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when left >= right' do
      expect(described_class.integer__lt_(ctx, i5, i3)).to equal(Frozone::Vm::FalseObject::FALSE)
      expect(described_class.integer__lt_(ctx, i3, i3)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.integer__le_' do
    it 'returns TRUE when left <= right' do
      expect(described_class.integer__le_(ctx, i3, i5)).to equal(Frozone::Vm::TrueObject::TRUE)
      expect(described_class.integer__le_(ctx, i3, i3)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when left > right' do
      expect(described_class.integer__le_(ctx, i5, i3)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.integer__ge_' do
    it 'returns TRUE when left >= right' do
      expect(described_class.integer__ge_(ctx, i5, i3)).to equal(Frozone::Vm::TrueObject::TRUE)
      expect(described_class.integer__ge_(ctx, i3, i3)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when left < right' do
      expect(described_class.integer__ge_(ctx, i3, i5)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.integer__gt_' do
    it 'returns TRUE when left > right' do
      expect(described_class.integer__gt_(ctx, i5, i3)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when left <= right' do
      expect(described_class.integer__gt_(ctx, i3, i5)).to equal(Frozone::Vm::FalseObject::FALSE)
      expect(described_class.integer__gt_(ctx, i3, i3)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.integer__eq_' do
    it 'returns TRUE when values are equal' do
      expect(described_class.integer__eq_(ctx, i3, Frozone::Vm::IntegerObject.new(3))).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FALSE when values differ' do
      expect(described_class.integer__eq_(ctx, i3, i5)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '.basic_object___id__' do
    it 'returns an IntegerObject' do
      expect(described_class.basic_object___id__(ctx, i3)).to be_a(Frozone::Vm::IntegerObject)
    end

    it 'returns the same value for the same object' do
      result1 = described_class.basic_object___id__(ctx, i3)
      result2 = described_class.basic_object___id__(ctx, i3)
      expect(result1.raw).to eq(result2.raw)
    end

    it 'returns different values for different objects' do
      a = Frozone::Vm::IntegerObject.new(1)
      b = Frozone::Vm::IntegerObject.new(1)
      expect(described_class.basic_object___id__(ctx, a).raw).not_to eq(
        described_class.basic_object___id__(ctx, b).raw
      )
    end
  end

  describe '.integer_hash' do
    it 'returns an IntegerObject' do
      expect(described_class.integer_hash(ctx, i3)).to be_a(Frozone::Vm::IntegerObject)
    end

    it 'returns the same hash for equal integer values' do
      a = Frozone::Vm::IntegerObject.new(42)
      b = Frozone::Vm::IntegerObject.new(42)
      expect(described_class.integer_hash(ctx, a).raw).to eq(described_class.integer_hash(ctx, b).raw)
    end

    it 'returns the Ruby integer hash value' do
      expect(described_class.integer_hash(ctx, i5).raw).to eq(5.hash)
    end
  end

  describe '.bool_object_for' do
    it 'returns TrueObject::TRUE for true' do
      expect(described_class.bool_object_for(true)).to equal(Frozone::Vm::TrueObject::TRUE)
    end

    it 'returns FalseObject::FALSE for false' do
      expect(described_class.bool_object_for(false)).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end
end
