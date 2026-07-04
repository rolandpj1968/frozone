require_relative '../../../../support/vm_loader'
require_relative '../../../../../lib/frozone/compiler/reachability'

# Minimal unit coverage for ReachabilityPass — the virtual seed
# nodes and the class transfer. Full integration coverage lives in
# integration_spec against real compiled programs.
RSpec.describe Frozone::Compiler::Analysis::Passes::ReachabilityPass do
  # Minimum viable top-level scope. Real ClassObject/ModuleObject aren't
  # instantiated here — we only need constants_table plumbing for the
  # class-node transfer.
  let(:top_level_scope) { double('scope', constants_table: {}) }
  let(:all_classes)     { {} }
  let(:seed_reachable_classes) { [] }
  let(:pass) do
    described_class.new(
      execute_block:          nil,
      user_methods:           {},
      top_level_scope:        top_level_scope,
      all_classes:            all_classes,
      seed_reachable_classes: seed_reachable_classes,
      instantiated_classes:   [],
    )
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

    it 'seeds each seed_reachable_classes entry as a class flat-name' do
      integer_cls = instance_double(Frozone::Vm::ModuleObject)
      allow(integer_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      all_classes[:Integer] = integer_cls
      seed_reachable_classes << :Integer << :MissingClass

      seeds = pass.seed
      expect(seeds).to include(Integer: :reachable)
      # MissingClass is asked for as reachable but the guard drops it since
      # it's not in all_classes — no spurious phantom node.
      expect(seeds).not_to include(MissingClass: :reachable)
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

  describe 'reflection call-site detection' do
    def const(sym)   = Frozone::Ast::ConstantRead.new(sym)
    def sym_lit(sym) = Frozone::Ast::SymbolLiteral.from(sym)
    def call(recv, name, *args) = Frozone::Ast::MethodCall.new(name, recv, args, [])

    it 'collects a ReflectionFinding for each reflection call in a walked body' do
      # `Foo.const_get(:Bar)` — tier :a
      body = call(const(:Foo), :const_get, sym_lit(:Bar))

      method = instance_double(Frozone::Vm::Method,
        body: body,
        optional_params: [],
        optional_kw_params: [],
      )
      allow(method).to receive(:is_a?).and_return(false)
      allow(method).to receive(:is_a?).with(Frozone::Vm::Method).and_return(true)

      foo_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Foo', name: 'Foo')
      allow(foo_cls).to receive(:is_a?).and_return(false)
      allow(foo_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(foo_cls).to receive(:eigenclass).and_return(nil)
      allow(foo_cls).to receive(:methods_table).and_return({ do_lookup: method })
      allow(foo_cls).to receive(:ancestors_list).and_return([])
      allow(foo_cls).to receive(:constants_table).and_return(nil)

      all_classes[:Foo] = foo_cls
      pass.transfer(:Foo, :reachable, ->(_) { :unreachable })

      expect(pass.reflection_findings.size).to eq(1)
      finding = pass.reflection_findings.first
      expect(finding.method_name).to eq(:const_get)
      expect(finding.tier).to eq(:a)
    end

    it 'classifies each site by receiver/arg shape into tier :a/:b/:c/:d' do
      # Two sites in one body: tier :a and tier :d
      # (Chain via a block-like arg-list — body just needs to contain both calls)
      a_call = call(const(:Foo), :const_get, sym_lit(:Bar))
      var_recv = call(nil, :some_object)
      var_arg = call(nil, :name_var)
      d_call = call(var_recv, :send, var_arg)
      # Compose: outer call whose args include both — walker recurses into children
      outer = call(nil, :harness, a_call, d_call)

      method = instance_double(Frozone::Vm::Method,
        body: outer,
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

      all_classes[:Foo] = foo_cls
      pass.transfer(:Foo, :reachable, ->(_) { :unreachable })

      tiers = pass.reflection_findings.map(&:tier)
      expect(tiers).to contain_exactly(:a, :d)
    end

    it 'no findings when no reflection calls appear' do
      # A body with a non-reflection MethodCall.
      body = call(const(:Foo), :some_regular_method)

      method = instance_double(Frozone::Vm::Method,
        body: body,
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

      all_classes[:Foo] = foo_cls
      pass.transfer(:Foo, :reachable, ->(_) { :unreachable })

      expect(pass.reflection_findings).to be_empty
    end
  end

  describe 'RubyClass class_uses: declaration' do
    it 'pushes declared class_uses when its class node fires' do
      # A universe class Regexp has `uses: [:RegexpError]` on its
      # RubyClass entry. When :Regexp fires reachable (via the
      # seed_reachable_classes seed), transfer_class runs push_class_uses
      # and roots RegexpError even without any Ruby AST reference.
      regexp_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Regexp', name: 'Regexp')
      allow(regexp_cls).to receive(:is_a?).and_return(false)
      allow(regexp_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      allow(regexp_cls).to receive(:methods_table).and_return(nil)
      allow(regexp_cls).to receive(:eigenclass).and_return(nil)
      allow(regexp_cls).to receive(:ancestors_list).and_return([])
      allow(regexp_cls).to receive(:constants_table).and_return(nil)

      regexp_error_cls = instance_double(Frozone::Vm::ModuleObject)
      all_classes[:Regexp] = regexp_cls
      all_classes[:RegexpError] = regexp_error_cls

      pass = described_class.new(
        execute_block:          nil,
        user_methods:           {},
        top_level_scope:        top_level_scope,
        all_classes:            all_classes,
        seed_reachable_classes: [:Regexp],
        instantiated_classes:   [],
        class_uses:             { Regexp: %i[RegexpError] },
      )

      result = pass.transfer(:Regexp, :reachable, ->(_) { :unreachable })
      expect(result.pushes).to include(RegexpError: :reachable)
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
  end

  describe '#transfer for :instantiated_classes virtual node' do
    it 'pushes flat-names for values whose class_object is in all_classes' do
      user_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'MyClass', name: 'MyClass')
      allow(user_cls).to receive(:is_a?).with(Frozone::Vm::ModuleObject).and_return(true)
      val = double('user object', class_object: user_cls)
      all_classes[:MyClass] = user_cls

      pass = described_class.new(
        execute_block:          nil,
        user_methods:           {},
        top_level_scope:        top_level_scope,
        all_classes:            all_classes,
        seed_reachable_classes: [],
        instantiated_classes:   [val],
      )
      result = pass.transfer(described_class::SEED_INSTANTIATED, :reachable, ->(_) { :unreachable })
      expect(result.pushes).to eq({ MyClass: :reachable })
    end

    it 'skips values whose class is not in all_classes' do
      # No universe-name filter anymore — the sole guard is @all_classes.key?
      # (spurious classes not in the closed-world snapshot don't pollute reach).
      absent_cls = instance_double(Frozone::Vm::ModuleObject, full_name: 'Absent', name: 'Absent')
      val = double('int-like', class_object: absent_cls)

      pass = described_class.new(
        execute_block:          nil,
        user_methods:           {},
        top_level_scope:        top_level_scope,
        all_classes:            all_classes,
        seed_reachable_classes: [],
        instantiated_classes:   [val],
      )
      result = pass.transfer(described_class::SEED_INSTANTIATED, :reachable, ->(_) { :unreachable })
      expect(result).to eq(Frozone::Compiler::Analysis::TransferResult::EMPTY)
    end
  end
end
