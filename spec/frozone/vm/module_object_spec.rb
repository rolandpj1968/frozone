require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::ModuleObject do
  let(:mod) { described_class.new(:TestMod, nil) }

  describe '#initialize' do
    it 'accepts a symbol name and nil namespace' do
      expect { described_class.new(:Foo, nil) }.not_to raise_error
    end

    it 'raises when name is not a Symbol' do
      expect { described_class.new("Foo", nil) }.to raise_error(RuntimeError)
    end
  end

  describe '#name' do
    it 'returns the module name' do
      expect(mod.name).to eq(:TestMod)
    end
  end

  describe '#to_s' do
    it 'returns "module <Name>"' do
      expect(mod.to_s).to eq("module TestMod")
    end
  end

  describe '#set_method / #get_method' do
    it 'stores and retrieves a method by symbol name' do
      m = make_method(mod, :foo)
      mod.set_method(:foo, m)
      expect(mod.get_method(:foo)).to equal(m)
    end

    it 'returns nil for an undefined method' do
      expect(mod.get_method(:undefined_zz)).to be_nil
    end

    it 'raises when get_method name is not a Symbol' do
      expect { mod.get_method("foo") }.to raise_error(RuntimeError)
    end

    it 'raises when set_method value is not a Method' do
      expect { mod.set_method(:foo, "not a method") }.to raise_error(RuntimeError)
    end

    it 'overwrites a previously set method' do
      m1 = make_method(mod, :foo)
      m2 = make_method(mod, :foo)
      mod.set_method(:foo, m1)
      mod.set_method(:foo, m2)
      expect(mod.get_method(:foo)).to equal(m2)
    end
  end

  describe '#set_constant / #get_constant' do
    it 'stores and retrieves a constant by symbol name' do
      val = Frozone::Vm::IntegerObject.new(42)
      mod.set_constant(:MY_CONST, val)
      expect(mod.get_constant(:MY_CONST)).to equal(val)
    end

    it 'returns nil for an undefined constant' do
      expect(mod.get_constant(:UNDEFINED_ZZ)).to be_nil
    end

    it 'raises when name is not a Symbol' do
      expect { mod.get_constant("MY_CONST") }.to raise_error(RuntimeError)
    end

    it 'overwrites a previously set constant' do
      val1 = Frozone::Vm::IntegerObject.new(1)
      val2 = Frozone::Vm::IntegerObject.new(2)
      mod.set_constant(:REDEF, val1)
      mod.set_constant(:REDEF, val2)
      expect(mod.get_constant(:REDEF)).to equal(val2)
    end
  end

  describe '.lookup_constant' do
    let(:base)  { Frozone::Vm::ClassObject.new(:LookupBase, nil, nil) }
    let(:child) { Frozone::Vm::ClassObject.new(:LookupChild, nil, base) }

    it 'finds a constant in the only scope' do
      val = Frozone::Vm::IntegerObject.new(1)
      base.set_constant(:ONE, val)
      expect(described_class.lookup_constant(:ONE, [base])).to equal(val)
    end

    it 'prefers inner (later) scope over outer scope' do
      outer = Frozone::Vm::ClassObject.new(:Outer, nil, nil)
      inner = Frozone::Vm::ClassObject.new(:Inner, nil, nil)
      outer_val = Frozone::Vm::IntegerObject.new(1)
      inner_val = Frozone::Vm::IntegerObject.new(2)
      outer.set_constant(:SHADOWED, outer_val)
      inner.set_constant(:SHADOWED, inner_val)
      expect(described_class.lookup_constant(:SHADOWED, [outer, inner])).to equal(inner_val)
    end

    it 'falls back to the class hierarchy when not found in any scope' do
      val = Frozone::Vm::IntegerObject.new(99)
      base.set_constant(:INHERITED, val)
      expect(described_class.lookup_constant(:INHERITED, [child])).to equal(val)
    end

    it 'returns nil when not found anywhere' do
      expect(described_class.lookup_constant(:TOTALLY_MISSING_ZZ, [base])).to be_nil
    end
  end
end
