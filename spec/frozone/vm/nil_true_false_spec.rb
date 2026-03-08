require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::NilObject do
  describe '::NIL' do
    it 'is a singleton' do
      expect(Frozone::Vm::NilObject::NIL).to be_a(described_class)
    end

    it 'is always the same object' do
      expect(Frozone::Vm::NilObject::NIL).to equal(Frozone::Vm::NilObject::NIL)
    end
  end

  describe '#to_s' do
    it 'returns "nil"' do
      expect(Frozone::Vm::NilObject::NIL.to_s).to eq('nil')
    end
  end

  describe '#truthy?' do
    it 'is falsy' do
      expect(Frozone::Vm::NilObject::NIL.truthy?).to be false
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end
end

RSpec.describe Frozone::Vm::TrueObject do
  describe '::TRUE' do
    it 'is a singleton' do
      expect(Frozone::Vm::TrueObject::TRUE).to be_a(described_class)
    end

    it 'is always the same object' do
      expect(Frozone::Vm::TrueObject::TRUE).to equal(Frozone::Vm::TrueObject::TRUE)
    end
  end

  describe '#to_s' do
    it 'returns "true"' do
      expect(Frozone::Vm::TrueObject::TRUE.to_s).to eq('true')
    end
  end

  describe '#truthy?' do
    it 'is truthy' do
      expect(Frozone::Vm::TrueObject::TRUE.truthy?).to be true
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end
end

RSpec.describe Frozone::Vm::FalseObject do
  describe '::FALSE' do
    it 'is a singleton' do
      expect(Frozone::Vm::FalseObject::FALSE).to be_a(described_class)
    end

    it 'is always the same object' do
      expect(Frozone::Vm::FalseObject::FALSE).to equal(Frozone::Vm::FalseObject::FALSE)
    end
  end

  describe '#to_s' do
    it 'returns "false"' do
      expect(Frozone::Vm::FalseObject::FALSE.to_s).to eq('false')
    end
  end

  describe '#truthy?' do
    it 'is falsy' do
      expect(Frozone::Vm::FalseObject::FALSE.truthy?).to be false
    end
  end

  describe '.new' do
    it 'is private' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end
end
