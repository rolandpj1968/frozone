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

  describe '#transfer_class constant-value walk' do
    # Runtime-state class refs that live in a class's constants_table
    # after load-time evaluation but leave no AST trace. Example:
    # `class Foo; CLASSES = [Bar, Baz]; end` — after load, the array
    # literal is gone; only the ArrayObject with live Class refs remains.
    it 'roots classes directly stored in the constants_table' do
      bar_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Bar', name: 'Bar')
      allow(bar_cls).to receive(:is_a?).and_return(false)
      allow(bar_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(bar_cls).to receive(:eigenclass).and_return(nil)
      allow(bar_cls).to receive(:methods_table).and_return(nil)
      allow(bar_cls).to receive(:ancestors_list).and_return([])
      allow(bar_cls).to receive(:constants_table).and_return(nil)

      foo_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Foo', name: 'Foo')
      allow(foo_cls).to receive(:is_a?).and_return(false)
      allow(foo_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(foo_cls).to receive(:eigenclass).and_return(nil)
      allow(foo_cls).to receive(:methods_table).and_return(nil)
      allow(foo_cls).to receive(:ancestors_list).and_return([])
      # Foo's constants_table holds a direct ref to Bar.
      allow(foo_cls).to receive(:constants_table).and_return({ Bar: bar_cls })

      all_classes[:Foo] = foo_cls
      all_classes[:Bar] = bar_cls

      result = pass.transfer(:Foo, :reachable, ->(_) { :unreachable })
      expect(result.pushes).to include(Bar: :reachable)
    end

    it 'roots classes embedded in an ArrayObject value (the CLASSES_CONST case)' do
      bar_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Bar', name: 'Bar')
      allow(bar_cls).to receive(:is_a?).and_return(false)
      allow(bar_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)

      arr_obj = instance_double(Frozone::Vm::ArrayObject, raw: [bar_cls])
      allow(arr_obj).to receive(:is_a?).and_return(false)
      allow(arr_obj).to receive(:is_a?).with(Frozone::Vm::ArrayObject).and_return(true)
      allow(arr_obj).to receive(:class_object).and_return(nil)  # skip class-object push

      foo_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Foo', name: 'Foo')
      allow(foo_cls).to receive(:is_a?).and_return(false)
      allow(foo_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(foo_cls).to receive(:eigenclass).and_return(nil)
      allow(foo_cls).to receive(:methods_table).and_return(nil)
      allow(foo_cls).to receive(:ancestors_list).and_return([])
      allow(foo_cls).to receive(:constants_table).and_return({ CLASSES: arr_obj })

      all_classes[:Foo] = foo_cls
      all_classes[:Bar] = bar_cls

      result = pass.transfer(:Foo, :reachable, ->(_) { :unreachable })
      expect(result.pushes).to include(Bar: :reachable)
    end

    it 'terminates on cyclic container values' do
      # A container that references itself must not cause infinite
      # recursion. seen-set guard makes this safe.
      cyclic_arr = instance_double(Frozone::Vm::ArrayObject)
      allow(cyclic_arr).to receive(:is_a?).and_return(false)
      allow(cyclic_arr).to receive(:is_a?).with(Frozone::Vm::ArrayObject).and_return(true)
      allow(cyclic_arr).to receive(:raw).and_return([cyclic_arr])
      allow(cyclic_arr).to receive(:class_object).and_return(nil)

      foo_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Foo', name: 'Foo')
      allow(foo_cls).to receive(:is_a?).and_return(false)
      allow(foo_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(foo_cls).to receive(:eigenclass).and_return(nil)
      allow(foo_cls).to receive(:methods_table).and_return(nil)
      allow(foo_cls).to receive(:ancestors_list).and_return([])
      allow(foo_cls).to receive(:constants_table).and_return({ CYC: cyclic_arr })

      all_classes[:Foo] = foo_cls

      expect { pass.transfer(:Foo, :reachable, ->(_) { :unreachable }) }.not_to raise_error
    end
  end

  describe 'RubyClass class_uses: declaration' do
    it 'pushes declared class_uses for a reached universe overlay' do
      # A universe class Regexp has `uses: [:RegexpError]` on its
      # RubyClass entry. When the universe overlay virtual node fires,
      # RegexpError is rooted even without any Ruby AST reference.
      regexp_cls = instance_double(Frozone::Vm::ModuleObject)
      allow(regexp_cls).to receive(:is_a?).and_return(false)
      allow(regexp_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(regexp_cls).to receive(:methods_table).and_return(nil)
      allow(regexp_cls).to receive(:eigenclass).and_return(nil)
      allow(regexp_cls).to receive(:full_name).and_return('Regexp')
      allow(regexp_cls).to receive(:name).and_return('Regexp')
      allow(top_level_scope).to receive(:constants_table).and_return({ Regexp: regexp_cls })

      regexp_error_cls = instance_double(Frozone::Vm::ModuleObject)
      all_classes[:RegexpError] = regexp_error_cls

      pass = described_class.new(
        execute_block:         nil,
        user_methods:          {},
        top_level_scope:       top_level_scope,
        all_classes:           all_classes,
        universe_class_names:  universe_class_names,
        instantiated_classes:  [],
        class_uses:            { Regexp: %i[RegexpError] },
      )

      # Fire the Regexp universe-overlay virtual node.
      node = described_class.universe_overlay_node(:Regexp)
      result = pass.transfer(node, :reachable, ->(_) { :unreachable })
      expect(result.pushes).to include(RegexpError: :reachable)
    end

    it 'skips class_uses entries that are in universe_class_names' do
      # If a class_uses declaration names a universe class, filter it —
      # universe is always emitted, no need to root.
      regexp_cls = instance_double(Frozone::Vm::ModuleObject)
      allow(regexp_cls).to receive(:is_a?).and_return(false)
      allow(regexp_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(regexp_cls).to receive(:methods_table).and_return(nil)
      allow(regexp_cls).to receive(:eigenclass).and_return(nil)
      allow(regexp_cls).to receive(:full_name).and_return('Regexp')
      allow(regexp_cls).to receive(:name).and_return('Regexp')
      allow(top_level_scope).to receive(:constants_table).and_return({ Regexp: regexp_cls })
      universe_class_names << 'MatchData'

      pass = described_class.new(
        execute_block:         nil,
        user_methods:          {},
        top_level_scope:       top_level_scope,
        all_classes:           all_classes,
        universe_class_names:  universe_class_names,
        instantiated_classes:  [],
        class_uses:            { Regexp: %i[MatchData] },
      )

      node = described_class.universe_overlay_node(:Regexp)
      result = pass.transfer(node, :reachable, ->(_) { :unreachable })
      expect(result.pushes).not_to include(MatchData: :reachable)
    end
  end

  describe 'intrinsic uses: declaration' do
    it 'roots classes declared in IntrinsicLowering.uses_of for an Intrinsics call in a reached body' do
      # Set up a class Foo whose body contains `Intrinsics.regexp_new(...)`.
      # Declared uses for regexp_new include :RegexpError → RegexpError
      # should be rooted even though it never appears as a ConstantRead
      # in the AST.
      recv = Frozone::Ast::ConstantRead.new(:Intrinsics)
      intrinsic_call = Frozone::Ast::MethodCall.new(:regexp_new, recv, [], [])

      method = instance_double(Frozone::Vm::Method,
        body: intrinsic_call,
        optional_params: [],
        optional_kw_params: [],
      )
      allow(method).to receive(:is_a?).and_return(false)
      allow(method).to receive(:is_a?).with(Frozone::Vm::Method).and_return(true)

      foo_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Foo', name: 'Foo')
      allow(foo_cls).to receive(:is_a?).and_return(false)
      allow(foo_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(foo_cls).to receive(:eigenclass).and_return(nil)
      allow(foo_cls).to receive(:methods_table).and_return({ do_match: method })
      allow(foo_cls).to receive(:ancestors_list).and_return([])
      allow(foo_cls).to receive(:constants_table).and_return(nil)

      regexp_error_cls = instance_double(Frozone::Vm::ModuleObject)
      all_classes[:Foo] = foo_cls
      all_classes[:RegexpError] = regexp_error_cls

      result = pass.transfer(:Foo, :reachable, ->(_) { :unreachable })
      expect(result.pushes).to include(RegexpError: :reachable)
    end

    it 'ignores Intrinsics calls whose declared classes are in universe_class_names' do
      # If an intrinsic's uses: entry names a universe class, it's
      # already emitted — skip pushing it into the reach set.
      recv = Frozone::Ast::ConstantRead.new(:Intrinsics)
      intrinsic_call = Frozone::Ast::MethodCall.new(:regexp_match, recv, [], [])

      method = instance_double(Frozone::Vm::Method,
        body: intrinsic_call,
        optional_params: [],
        optional_kw_params: [],
      )
      allow(method).to receive(:is_a?).and_return(false)
      allow(method).to receive(:is_a?).with(Frozone::Vm::Method).and_return(true)

      foo_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Foo', name: 'Foo')
      allow(foo_cls).to receive(:is_a?).and_return(false)
      allow(foo_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(foo_cls).to receive(:eigenclass).and_return(nil)
      allow(foo_cls).to receive(:methods_table).and_return({ m: method })
      allow(foo_cls).to receive(:ancestors_list).and_return([])
      allow(foo_cls).to receive(:constants_table).and_return(nil)

      universe_class_names << 'MatchData'  # pretend MatchData is universe
      all_classes[:Foo] = foo_cls

      result = pass.transfer(:Foo, :reachable, ->(_) { :unreachable })
      expect(result.pushes).not_to include(MatchData: :reachable)
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
