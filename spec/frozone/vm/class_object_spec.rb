require_relative '../../support/vm_loader'

RSpec.describe Frozone::Vm::ClassObject do
  # Isolated hierarchy for method/constant lookup tests (avoids touching global Core classes)
  let(:root_class)  { described_class.new(sym(:Root), nil, nil) }
  let(:base_class)  { described_class.new(sym(:Base), nil, root_class) }
  let(:child_class) { described_class.new(sym(:Child), nil, base_class) }
  let(:mod)         { Frozone::Vm::ModuleObject.new(sym(:MyMod), nil) }

  describe 'Core bootstrap' do
    it 'patch_class_object sets CLASS_CLASS as class_object for bootstrapped classes' do
      expect(Frozone::Vm::Core::BASIC_OBJECT_CLASS.instance_variable_get(:@class_object)).to equal(Frozone::Vm::Core::CLASS_CLASS)
      expect(Frozone::Vm::Core::MODULE_CLASS.instance_variable_get(:@class_object)).to equal(Frozone::Vm::Core::CLASS_CLASS)
      expect(Frozone::Vm::Core::CLASS_CLASS.instance_variable_get(:@class_object)).to equal(Frozone::Vm::Core::CLASS_CLASS)
    end

    it 'newly created ClassObjects also use CLASS_CLASS' do
      klass = described_class.new(sym(:PostBootstrap), nil, Frozone::Vm::Core::OBJECT_CLASS)
      expect(klass.instance_variable_get(:@class_object)).to equal(Frozone::Vm::Core::CLASS_CLASS)
    end
  end

  describe '#lookup_method' do
    it 'finds a method defined directly on the class' do
      m = make_method(base_class, :greet)
      base_class.set_method(sym(:greet), m)
      expect(base_class.lookup_method(sym(:greet))).to equal(m)
    end

    it 'returns nil for an undefined method' do
      expect(root_class.lookup_method(sym(:nonexistent))).to be_nil
    end

    it 'finds a method from the superclass' do
      m = make_method(base_class, :inherited)
      base_class.set_method(sym(:inherited), m)
      expect(child_class.lookup_method(sym(:inherited))).to equal(m)
    end

    it 'prefers own method over superclass method' do
      super_m = make_method(base_class, :foo)
      child_m = make_method(child_class, :foo)
      base_class.set_method(sym(:foo), super_m)
      child_class.set_method(sym(:foo), child_m)
      expect(child_class.lookup_method(sym(:foo))).to equal(child_m)
    end

    it 'finds a method from an included module' do
      m = make_method(base_class, :mod_method)
      mod.set_method(sym(:mod_method), m)
      base_class.add_module(mod)
      expect(base_class.lookup_method(sym(:mod_method))).to equal(m)
    end

    it 'prefers own method over module method' do
      mod_m = make_method(base_class, :foo)
      own_m = make_method(base_class, :foo)
      mod.set_method(sym(:foo), mod_m)
      base_class.add_module(mod)
      base_class.set_method(sym(:foo), own_m)
      expect(base_class.lookup_method(sym(:foo))).to equal(own_m)
    end

    it 'finds a method from a prepended module before own methods' do
      own_m = make_method(base_class, :foo)
      pre_m = make_method(base_class, :foo)
      base_class.set_method(sym(:foo), own_m)
      prepend_mod = Frozone::Vm::ModuleObject.new(sym(:Prepended), nil)
      prepend_mod.set_method(sym(:foo), pre_m)
      base_class.prepend_module(prepend_mod)
      expect(base_class.lookup_method(sym(:foo))).to equal(pre_m)
    end

    it 'raises if name is not a SymbolObject' do
      expect { base_class.lookup_method(:foo) }.to raise_error(RuntimeError)
    end
  end

  describe '#lookup_constant' do
    it 'finds a constant defined on the class' do
      val = Frozone::Vm::IntegerObject.new(1)
      base_class.set_constant(sym(:MY_CONST), val)
      expect(base_class.lookup_constant(sym(:MY_CONST))).to equal(val)
    end

    it 'returns nil for an undefined constant' do
      expect(base_class.lookup_constant(sym(:NOPE))).to be_nil
    end

    it 'finds a constant from the superclass' do
      val = Frozone::Vm::IntegerObject.new(2)
      base_class.set_constant(sym(:SUPER_CONST), val)
      expect(child_class.lookup_constant(sym(:SUPER_CONST))).to equal(val)
    end

    it 'prefers own constant over superclass constant' do
      super_val = Frozone::Vm::IntegerObject.new(1)
      child_val = Frozone::Vm::IntegerObject.new(2)
      base_class.set_constant(sym(:SHADOWED), super_val)
      child_class.set_constant(sym(:SHADOWED), child_val)
      expect(child_class.lookup_constant(sym(:SHADOWED))).to equal(child_val)
    end
  end
end
