require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/reachability'

# Minimal unit coverage for ReachabilityPass — the four virtual seed
# nodes and the class transfer. Full integration coverage lives in
# integration_spec against real compiled programs.
RSpec.describe Frozone::Compiler::Analysis::Passes::ReachabilityPass do
  # Minimum viable top-level scope. Real ClassObject/ModuleObject aren't
  # instantiated here — we only need constants_table for universe overlay
  # lookup, and the four virtual seeds are exercised individually.
  let(:top_level_scope) { double('scope', constants_table: {}) }
  let(:all_classes)     { {} }
  let(:universe_class_names) { Set.new }
  let(:pass) do
    described_class.new(
      execute_block:         nil,
      user_methods:          {},
      top_level_scope:       top_level_scope,
      all_classes:           all_classes,
      universe_class_names:  universe_class_names,
      instantiated_classes:  [],
    )
  end

  describe '.universe_overlay_node' do
    it 'produces a tagged tuple with symbol name' do
      node = described_class.universe_overlay_node(:Object)
      expect(node).to eq([:universe_overlay, :Object])
      expect(node).to be_frozen
    end

    it 'coerces String to Symbol' do
      expect(described_class.universe_overlay_node('Object')).to eq([:universe_overlay, :Object])
    end
  end

  describe '#seed' do
    it 'includes the three fixed virtual seed nodes' do
      seeds = pass.seed
      expect(seeds).to include(
        described_class::SEED_EXECUTE_BLOCK => :reachable,
        described_class::SEED_USER_METHODS  => :reachable,
        described_class::SEED_INSTANTIATED  => :reachable,
      )
    end

    it 'adds universe overlay nodes only for classes present in top_level_scope' do
      integer_cls = instance_double(Frozone::Vm::ModuleObject)
      allow(integer_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(top_level_scope).to receive(:constants_table).and_return({ Integer: integer_cls })
      universe_class_names << 'Integer' << 'MissingClass'

      seeds = pass.seed
      expect(seeds).to include(described_class.universe_overlay_node(:Integer) => :reachable)
      expect(seeds).not_to include(described_class.universe_overlay_node(:MissingClass))
    end
  end

  describe '#transfer for unknown node kinds' do
    it 'returns EMPTY for unknown virtual-node tag' do
      result = pass.transfer([:__bogus__], :reachable, ->(_) { :unreachable })
      expect(result).to eq(Frozone::Compiler::Analysis::TransferResult::EMPTY)
    end

    it 'returns EMPTY for unknown class flat-name' do
      result = pass.transfer(:NotAClass, :reachable, ->(_) { :unreachable })
      expect(result).to eq(Frozone::Compiler::Analysis::TransferResult::EMPTY)
    end

    it 'returns EMPTY when value is :unreachable' do
      result = pass.transfer(:AnyNode, :unreachable, ->(_) { :unreachable })
      expect(result).to eq(Frozone::Compiler::Analysis::TransferResult::EMPTY)
    end
  end

  describe '#transfer for :execute_block virtual node' do
    it 'is a no-op when execute_block is nil' do
      result = pass.transfer(described_class::SEED_EXECUTE_BLOCK, :reachable, ->(_) { :unreachable })
      expect(result).to eq(Frozone::Compiler::Analysis::TransferResult::EMPTY)
    end
  end

  describe '#transfer for :instantiated_classes virtual node' do
    it 'pushes flat-names for values whose class_object is in all_classes' do
      user_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'MyClass', name: 'MyClass')
      allow(user_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      val = double('user object', class_object: user_cls)
      all_classes[:MyClass] = user_cls

      pass = described_class.new(
        execute_block:         nil,
        user_methods:          {},
        top_level_scope:       top_level_scope,
        all_classes:           all_classes,
        universe_class_names:  universe_class_names,
        instantiated_classes:  [val],
      )
      result = pass.transfer(described_class::SEED_INSTANTIATED, :reachable, ->(_) { :unreachable })
      expect(result.pushes).to eq({ MyClass: :reachable })
    end

    it 'skips values whose class is in universe_class_names' do
      universe_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Integer', name: 'Integer')
      val = double('int-like', class_object: universe_cls)
      universe_class_names << 'Integer'

      pass = described_class.new(
        execute_block:         nil,
        user_methods:          {},
        top_level_scope:       top_level_scope,
        all_classes:           all_classes,
        universe_class_names:  universe_class_names,
        instantiated_classes:  [val],
      )
      result = pass.transfer(described_class::SEED_INSTANTIATED, :reachable, ->(_) { :unreachable })
      expect(result).to eq(Frozone::Compiler::Analysis::TransferResult::EMPTY)
    end
  end
end
