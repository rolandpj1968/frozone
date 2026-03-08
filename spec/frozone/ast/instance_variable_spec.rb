require_relative '../../support/vm_loader'

RSpec.describe Frozone::Ast::InstanceVariableRead do
  let(:klass) { Frozone::Vm::Core::OBJECT_CLASS }
  let(:obj)   { Frozone::Vm::ObjectObject.new(klass) }
  let(:ctx)   { make_context(the_self: obj) }

  describe '#initialize' do
    it 'accepts a SymbolObject name' do
      expect { described_class.new(sym(:@x)) }.not_to raise_error
    end

    it 'raises when name is a raw Symbol' do
      expect { described_class.new(:@x) }.to raise_error(RuntimeError)
    end

    it 'raises when name is a String' do
      expect { described_class.new("@x") }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'returns NilObject::NIL for an unset instance variable' do
      result = described_class.new(sym(:@x)).evaluate(ctx)
      expect(result).to equal(Frozone::Vm::NilObject::NIL)
    end

    it 'reads a previously written instance variable' do
      obj.set_ivar(sym(:@x), Frozone::Vm::IntegerObject.new(42))
      result = described_class.new(sym(:@x)).evaluate(ctx)
      expect(result.raw).to eq(42)
    end

    it 'reads from self, not from a different object' do
      other = Frozone::Vm::ObjectObject.new(klass)
      other.set_ivar(sym(:@x), Frozone::Vm::IntegerObject.new(99))
      result = described_class.new(sym(:@x)).evaluate(ctx)
      expect(result).to equal(Frozone::Vm::NilObject::NIL)
    end
  end

  describe '#to_s' do
    it 'includes the ivar name' do
      expect(described_class.new(sym(:@foo)).to_s).to include("@foo")
    end
  end
end

RSpec.describe Frozone::Ast::InstanceVariableWrite do
  let(:klass) { Frozone::Vm::Core::OBJECT_CLASS }
  let(:obj)   { Frozone::Vm::ObjectObject.new(klass) }
  let(:ctx)   { make_context(the_self: obj) }

  describe '#initialize' do
    it 'accepts a SymbolObject name and value Node' do
      expect { described_class.new(sym(:@x), Frozone::Ast::NilLiteral::NIL) }.not_to raise_error
    end

    it 'raises when name is a raw Symbol' do
      expect { described_class.new(:@x, Frozone::Ast::NilLiteral::NIL) }.to raise_error(RuntimeError)
    end

    it 'raises when value_node is not a Node' do
      expect { described_class.new(sym(:@x), "bad") }.to raise_error(RuntimeError)
    end
  end

  describe '#evaluate' do
    it 'writes to the instance variable and returns the value' do
      node = described_class.new(sym(:@x), Frozone::Ast::IntegerLiteral.from(7))
      result = node.evaluate(ctx)
      expect(result.raw).to eq(7)
      expect(obj.get_ivar(sym(:@x)).raw).to eq(7)
    end

    it 'overwrites an existing instance variable' do
      obj.set_ivar(sym(:@x), Frozone::Vm::IntegerObject.new(1))
      described_class.new(sym(:@x), Frozone::Ast::IntegerLiteral.from(2)).evaluate(ctx)
      expect(obj.get_ivar(sym(:@x)).raw).to eq(2)
    end

    it 'writes to self, not to other objects' do
      other = Frozone::Vm::ObjectObject.new(klass)
      described_class.new(sym(:@x), Frozone::Ast::IntegerLiteral.from(5)).evaluate(ctx)
      expect(other.get_ivar(sym(:@x))).to equal(Frozone::Vm::NilObject::NIL)
    end
  end

  describe '#to_s' do
    it 'includes the ivar name' do
      expect(described_class.new(sym(:@foo), Frozone::Ast::NilLiteral::NIL).to_s).to include("@foo")
    end
  end
end
