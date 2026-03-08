require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::ModuleObject do
  let(:mod) { described_class.new(sym(:TestMod), nil) }

  describe '#initialize' do
    it 'accepts a SymbolObject name and nil namespace' do
      expect { described_class.new(sym(:Foo), nil) }.not_to raise_error
    end

    it 'raises when name is not a SymbolObject' do
      expect { described_class.new(:Foo, nil) }.to raise_error(RuntimeError)
    end

    it 'raises when name is a String' do
      expect { described_class.new("Foo", nil) }.to raise_error(RuntimeError)
    end
  end

  describe '#name' do
    it 'returns the module name as a SymbolObject' do
      expect(mod.name).to eq(sym(:TestMod))
    end
  end

  describe '#to_s' do
    it 'returns "module <Name>"' do
      expect(mod.to_s).to eq("module TestMod")
    end
  end

  describe '#set_method / #get_method' do
    it 'stores and retrieves a method by SymbolObject name' do
      m = make_method(mod, :foo)
      mod.set_method(sym(:foo), m)
      expect(mod.get_method(sym(:foo))).to equal(m)
    end

    it 'returns nil for an undefined method' do
      expect(mod.get_method(sym(:undefined_zz))).to be_nil
    end

    it 'raises when get_method name is not a SymbolObject' do
      expect { mod.get_method(:foo) }.to raise_error(RuntimeError)
    end

    it 'raises when set_method name is not a SymbolObject' do
      m = make_method(mod, :foo)
      expect { mod.set_method(:foo, m) }.to raise_error(RuntimeError)
    end

    it 'raises when set_method value is not a Method' do
      expect { mod.set_method(sym(:foo), "not a method") }.to raise_error(RuntimeError)
    end

    it 'overwrites a previously set method' do
      m1 = make_method(mod, :foo)
      m2 = make_method(mod, :foo)
      mod.set_method(sym(:foo), m1)
      mod.set_method(sym(:foo), m2)
      expect(mod.get_method(sym(:foo))).to equal(m2)
    end
  end

  describe '#set_constant / #get_constant' do
    it 'stores and retrieves a constant by SymbolObject name' do
      val = Frozone::Vm::IntegerObject.new(42)
      mod.set_constant(sym(:MY_CONST), val)
      expect(mod.get_constant(sym(:MY_CONST))).to equal(val)
    end

    it 'returns nil for an undefined constant' do
      expect(mod.get_constant(sym(:UNDEFINED_ZZ))).to be_nil
    end

    it 'raises when name is not a SymbolObject' do
      expect { mod.get_constant(:MY_CONST) }.to raise_error(RuntimeError)
    end

    it 'overwrites a previously set constant' do
      val1 = Frozone::Vm::IntegerObject.new(1)
      val2 = Frozone::Vm::IntegerObject.new(2)
      mod.set_constant(sym(:REDEF), val1)
      mod.set_constant(sym(:REDEF), val2)
      expect(mod.get_constant(sym(:REDEF))).to equal(val2)
    end
  end

  describe '.lookup_constant' do
    let(:base)  { Frozone::Vm::ClassObject.new(sym(:LookupBase), nil, nil) }
    let(:child) { Frozone::Vm::ClassObject.new(sym(:LookupChild), nil, base) }

    it 'finds a constant in the only scope' do
      val = Frozone::Vm::IntegerObject.new(1)
      base.set_constant(sym(:ONE), val)
      expect(described_class.lookup_constant(sym(:ONE), [base])).to equal(val)
    end

    it 'prefers inner (later) scope over outer scope' do
      outer = Frozone::Vm::ClassObject.new(sym(:Outer), nil, nil)
      inner = Frozone::Vm::ClassObject.new(sym(:Inner), nil, nil)
      outer_val = Frozone::Vm::IntegerObject.new(1)
      inner_val = Frozone::Vm::IntegerObject.new(2)
      outer.set_constant(sym(:SHADOWED), outer_val)
      inner.set_constant(sym(:SHADOWED), inner_val)
      expect(described_class.lookup_constant(sym(:SHADOWED), [outer, inner])).to equal(inner_val)
    end

    it 'falls back to the class hierarchy when not found in any scope' do
      val = Frozone::Vm::IntegerObject.new(99)
      base.set_constant(sym(:INHERITED), val)
      expect(described_class.lookup_constant(sym(:INHERITED), [child])).to equal(val)
    end

    it 'returns nil when not found anywhere' do
      expect(described_class.lookup_constant(sym(:TOTALLY_MISSING_ZZ), [base])).to be_nil
    end
  end
end
