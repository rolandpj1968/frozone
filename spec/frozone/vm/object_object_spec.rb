require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::ObjectObject do
  let(:klass) { Frozone::Vm::Core::OBJECT_CLASS }

  describe '#initialize' do
    it 'accepts a ClassObject' do
      expect { described_class.new(klass) }.not_to raise_error
    end

    it 'raises when given a non-ClassObject' do
      expect { described_class.new("not a class") }.to raise_error(RuntimeError, /ClassObject/)
    end
  end

  describe '#truthy?' do
    it 'is true for a regular object' do
      expect(described_class.new(klass).truthy?).to be true
    end

    it 'is false for NilObject::NIL' do
      expect(Frozone::Vm::NilObject::NIL.truthy?).to be false
    end

    it 'is false for FalseObject::FALSE' do
      expect(Frozone::Vm::FalseObject::FALSE.truthy?).to be false
    end

    it 'is true for TrueObject::TRUE' do
      expect(Frozone::Vm::TrueObject::TRUE.truthy?).to be true
    end

    it 'is true for a StringObject' do
      expect(Frozone::Vm::StringObject.new("").truthy?).to be true
    end

    it 'is true for an IntegerObject (including 0)' do
      expect(Frozone::Vm::IntegerObject.new(0).truthy?).to be true
    end
  end

  describe '#lookup_instance_method' do
    it 'finds a method defined on the class' do
      test_class = Frozone::Vm::ClassObject.new(sym(:TestLookup), nil, klass)
      m = make_method(test_class, :greet)
      test_class.set_method(sym(:greet), m)
      obj = described_class.new(test_class)
      expect(obj.lookup_instance_method(sym(:greet))).to equal(m)
    end

    it 'returns nil for an undefined method' do
      obj = described_class.new(klass)
      expect(obj.lookup_instance_method(sym(:totally_nonexistent_zz))).to be_nil
    end

    it 'finds a method inherited from a superclass' do
      parent_class = Frozone::Vm::ClassObject.new(sym(:ParentLookup), nil, klass)
      child_class  = Frozone::Vm::ClassObject.new(sym(:ChildLookup), nil, parent_class)
      m = make_method(parent_class, :inherited)
      parent_class.set_method(sym(:inherited), m)
      obj = described_class.new(child_class)
      expect(obj.lookup_instance_method(sym(:inherited))).to equal(m)
    end
  end
end
