require_relative '../../support/vm_loader'
require_relative '../../../lib/frozone/compiler/reachability'

# Unit coverage for the flat-name canonicaliser helpers. These are the
# single choke point for every "convert full_name to flat form" site
# in the compiler; the escape rule is load-bearing for collision safety.
RSpec.describe Frozone::Compiler::Reachability do
  describe '.flatten' do
    it 'passes through simple names unchanged' do
      expect(described_class.flatten('Foo')).to eq('Foo')
      expect(described_class.flatten('Integer')).to eq('Integer')
    end

    it 'collapses `::` to `_`' do
      expect(described_class.flatten('Foo::Bar')).to eq('Foo_Bar')
      expect(described_class.flatten('Frozone::Vm::ObjectObject')).to eq('Frozone_Vm_ObjectObject')
    end

    it 'escapes source `_` to `__` before collapsing `::`' do
      # Disambiguation: bare `Foo_Bar` must not collide with nested `Foo::Bar`.
      expect(described_class.flatten('Foo_Bar')).to eq('Foo__Bar')
      expect(described_class.flatten('Foo::Bar')).to eq('Foo_Bar')
    end

    it 'handles both escapes on the same name' do
      # `Foo::Bar_Baz` — nested with underscore in the leaf.
      expect(described_class.flatten('Foo::Bar_Baz')).to eq('Foo_Bar__Baz')
      # `Foo_X::Bar` — underscore in the outer.
      expect(described_class.flatten('Foo_X::Bar')).to eq('Foo__X_Bar')
    end

    it 'coerces non-String input via to_s' do
      expect(described_class.flatten(:Foo)).to eq('Foo')
    end
  end

  describe '.flat_name' do
    it 'returns a Symbol from a Vm class-like object' do
      cls = double('class', full_name: 'Foo::Bar', name: 'Bar')
      expect(described_class.flat_name(cls)).to eq(:Foo_Bar)
    end

    it 'falls back to name when full_name is nil' do
      cls = double('class', full_name: nil, name: 'Foo')
      expect(described_class.flat_name(cls)).to eq(:Foo)
    end

    it 'applies the escape rule end-to-end' do
      cls = double('class', full_name: 'Foo_X', name: 'Foo_X')
      expect(described_class.flat_name(cls)).to eq(:Foo__X)
    end
  end

  describe '.compose_flat' do
    it 'returns the escaped short-name Symbol when prefix is nil' do
      expect(described_class.compose_flat(nil, :Foo)).to eq(:Foo)
      expect(described_class.compose_flat(nil, :Foo_X)).to eq(:Foo__X)
    end

    it 'joins prefix and escaped short-name with underscore' do
      expect(described_class.compose_flat(:Foo, :Bar)).to eq(:Foo_Bar)
      expect(described_class.compose_flat(:Foo, :Bar_Y)).to eq(:Foo_Bar__Y)
    end

    it 'assumes prefix is already-flat (does NOT re-escape it)' do
      # Callers pass a prefix produced by a previous flat_name / compose_flat
      # call, which already has the escape applied. Re-escaping would
      # double-count. The `Foo__X` in the prefix stays literal.
      expect(described_class.compose_flat(:Foo__X, :Bar)).to eq(:Foo__X_Bar)
    end

    it 'produces the same result as flatten for equivalent inputs' do
      # compose_flat(:Foo, :Bar_Y) should equal flatten('Foo::Bar_Y') —
      # the whole point of the escape rule is that incremental composition
      # matches single-pass flattening.
      expect(described_class.compose_flat(:Foo, :Bar_Y).to_s)
        .to eq(described_class.flatten('Foo::Bar_Y'))
    end
  end

  describe 'reflection method-name detection' do
    def intrinsics_call(name, *args)
      recv = Frozone::Ast::ConstantRead.new(:Intrinsics)
      Frozone::Ast::MethodCall.new(name, recv, args, [])
    end

    def make_method(body)
      m = instance_double(Frozone::Vm::Method, body: body)
      allow(m).to receive(:is_a?).and_return(false)
      allow(m).to receive(:is_a?).with(Frozone::Vm::Method).and_return(true)
      m
    end

    def make_class(methods)
      cls = double('class', methods_table: methods)
      cls
    end

    describe '.CANONICAL_REFLECTION_METHOD_NAMES' do
      it 'contains the seven canonical reflection method names' do
        expect(described_class::CANONICAL_REFLECTION_METHOD_NAMES).to eq(
          Set.new(%i[send __send__ public_send
                     instance_variable_get instance_variable_set
                     const_get const_set])
        )
      end
    end

    describe '.body_reaches_reflection_intrinsic?' do
      it 'is true for a direct Intrinsics.basic_object___send__ call' do
        body = intrinsics_call(:basic_object___send__)
        expect(described_class.body_reaches_reflection_intrinsic?(body)).to be true
      end

      it 'is false for a non-reflection Intrinsics call' do
        body = intrinsics_call(:regexp_new)
        expect(described_class.body_reaches_reflection_intrinsic?(body)).to be false
      end

      it 'is false for nil body' do
        expect(described_class.body_reaches_reflection_intrinsic?(nil)).to be false
      end
    end

    describe '.compute_reflection_method_names' do
      it 'returns the canonical set when no classes contribute aliases' do
        result = described_class.compute_reflection_method_names({})
        expect(result).to eq(described_class::CANONICAL_REFLECTION_METHOD_NAMES)
      end

      it 'adds an alias whose method body reaches a reflection intrinsic' do
        # `alias my_send __send__` — the aliased method's body IS __send__'s
        # body (an Intrinsics.basic_object___send__ delegation).
        aliased_body = intrinsics_call(:basic_object___send__)
        cls = make_class({ my_send: make_method(aliased_body) })
        result = described_class.compute_reflection_method_names({ Foo: cls })
        expect(result).to include(:my_send)
        expect(result).to include(*described_class::CANONICAL_REFLECTION_METHOD_NAMES)
      end

      it 'does NOT add methods whose bodies only call non-reflection intrinsics' do
        body = intrinsics_call(:regexp_new)
        cls = make_class({ compile: make_method(body) })
        result = described_class.compute_reflection_method_names({ Foo: cls })
        expect(result).not_to include(:compile)
      end

      it 'ignores methods_table entries that are not Vm::Method (e.g. RubyClass override hashes)' do
        cls = make_class({ some_override: { params: [], body: 'C++ body string' } })
        expect { described_class.compute_reflection_method_names({ Foo: cls }) }.not_to raise_error
      end
    end

    describe '.each_reflection_call_in' do
      let(:reflection_names) { described_class::CANONICAL_REFLECTION_METHOD_NAMES }

      it 'yields MethodCall nodes whose name is a reflection name' do
        # `foo.send(:bar)` — direct reflection call site
        recv = Frozone::Ast::ConstantRead.new(:Foo)
        call = Frozone::Ast::MethodCall.new(:send, recv, [], [])

        yielded = []
        described_class.each_reflection_call_in(call, reflection_names) { |n| yielded << n }
        expect(yielded).to eq([call])
      end

      it 'does NOT yield non-reflection MethodCall nodes' do
        recv = Frozone::Ast::ConstantRead.new(:Foo)
        call = Frozone::Ast::MethodCall.new(:some_method, recv, [], [])

        yielded = []
        described_class.each_reflection_call_in(call, reflection_names) { |n| yielded << n }
        expect(yielded).to be_empty
      end

      it 'recurses into children' do
        inner_recv = Frozone::Ast::ConstantRead.new(:Foo)
        inner = Frozone::Ast::MethodCall.new(:const_get, inner_recv, [], [])
        # Wrap in an outer call whose arg is the reflection call.
        outer_recv = Frozone::Ast::ConstantRead.new(:Bar)
        outer = Frozone::Ast::MethodCall.new(:innocent, outer_recv, [inner], [])

        yielded = []
        described_class.each_reflection_call_in(outer, reflection_names) { |n| yielded << n }
        expect(yielded).to eq([inner])
      end
    end
  end

  describe '.eigenclass_name and .eigenclass_flat' do
    let(:cls) { double('class', full_name: 'Foo::Bar', name: 'Bar') }

    it 'appends EIG_SUFFIX to the flattened name' do
      expect(described_class.eigenclass_name(cls)).to eq("Foo_Bar#{described_class::EIG_SUFFIX}")
    end

    it 'symbolises via eigenclass_flat' do
      expect(described_class.eigenclass_flat(cls)).to eq(:"Foo_Bar#{described_class::EIG_SUFFIX}")
    end

    it 'is collision-safe against a user class named with the same trailer' do
      # Under EIG_SUFFIX = "_eig" (future rename), user class Foo_eig
      # would flatten to Foo__eig (escape kicks in) vs eigenclass-of-Foo
      # producing Foo_eig. Distinct. This test asserts the escape's
      # role without depending on the current EIG_SUFFIX value.
      user_named_like_trailer = double('class',
        full_name: "Foo#{described_class::EIG_SUFFIX}",
        name: "Foo#{described_class::EIG_SUFFIX}")
      eigen_of_foo = described_class.eigenclass_name(double('class', full_name: 'Foo', name: 'Foo'))
      expect(described_class.flat_name(user_named_like_trailer).to_s)
        .not_to eq(eigen_of_foo)
    end
  end
end
