require_relative '../../../support/functional_helper'
require_relative '../../../../lib/frozone/compiler/analysis/predicate_canonicity'

RSpec.describe Frozone::Compiler::Analysis::PredicateCanonicity do
  # `functional_helper.rb` runs load_core in before(:suite) so
  # CANONICAL_PREDICATE_BODIES is populated by the time these run.

  let(:pc) { described_class }

  describe 'NARROWING_PREDICATES' do
    it 'covers the intended predicate set' do
      expect(pc::NARROWING_PREDICATES).to eq(%i[is_a? kind_of? instance_of? nil?])
    end
  end

  describe 'canonical body capture' do
    it 'populates all four predicate names' do
      caps = Frozone::Vm::CANONICAL_PREDICATE_BODIES
      pc::NARROWING_PREDICATES.each do |name|
        expect(caps).to have_key(name), "expected canonical for #{name}"
        expect(caps[name]).not_to be_empty
      end
    end

    it 'nil? has two canonical bodies (Kernel + NilClass)' do
      # Kernel#nil? = false; NilClass#nil? = true. Both canonical.
      expect(Frozone::Vm::CANONICAL_PREDICATE_BODIES[:nil?].size).to eq(2)
    end

    it 'is_a? and kind_of? share the same body (alias)' do
      # `alias kind_of? is_a?` in Kernel — Method#alias_as preserves body ref.
      is_a_body = Frozone::Vm::CANONICAL_PREDICATE_BODIES[:is_a?].first
      kind_of_body = Frozone::Vm::CANONICAL_PREDICATE_BODIES[:kind_of?].first
      expect(kind_of_body).to be(is_a_body)
    end
  end

  describe '.body_canonical?' do
    it 'returns true for a captured body' do
      m = Frozone::Vm::Core::OBJECT_CLASS.lookup_method(:is_a?)
      expect(pc.body_canonical?(:is_a?, m.body)).to be true
    end

    it 'returns false for an arbitrary foreign body' do
      foreign_body = Frozone::Ast::NilLiteral::NIL
      expect(pc.body_canonical?(:is_a?, foreign_body)).to be false
    end

    it 'returns false for nil body' do
      expect(pc.body_canonical?(:is_a?, nil)).to be false
    end

    it 'returns false for an unknown predicate name' do
      m = Frozone::Vm::Core::OBJECT_CLASS.lookup_method(:is_a?)
      expect(pc.body_canonical?(:not_a_predicate, m.body)).to be false
    end

    it 'accepts either canonical body for nil?' do
      kernel_nil = Frozone::Vm::Core::OBJECT_CLASS.lookup_method(:nil?)
      nil_nil = Frozone::Vm::Core::NIL_CLASS_CLASS.lookup_method(:nil?)
      expect(pc.body_canonical?(:nil?, kernel_nil.body)).to be true
      expect(pc.body_canonical?(:nil?, nil_nil.body)).to be true
    end
  end

  describe '.class_uses_canonical?' do
    it 'Object uses canonical is_a? (inherited from Kernel)' do
      expect(pc.class_uses_canonical?(Frozone::Vm::Core::OBJECT_CLASS, :is_a?)).to be true
    end

    it 'Integer uses canonical is_a? (inherited)' do
      expect(pc.class_uses_canonical?(Frozone::Vm::Core::INTEGER_CLASS, :is_a?)).to be true
    end

    it 'NilClass uses canonical nil? (own definition)' do
      expect(pc.class_uses_canonical?(Frozone::Vm::Core::NIL_CLASS_CLASS, :nil?)).to be true
    end

    it 'Integer uses canonical nil? (inherited Kernel false-returning body)' do
      expect(pc.class_uses_canonical?(Frozone::Vm::Core::INTEGER_CLASS, :nil?)).to be true
    end
  end

  describe '.class_uses_canonical? — detects overrides' do
    let(:foo) { Frozone::Vm::ClassObject.new(:Foo, nil, Frozone::Vm::Core::OBJECT_CLASS) }

    it 'flags a Foo#is_a? override as non-canonical' do
      # Install a foreign body as Foo#is_a?.
      foreign_body = Frozone::Ast::NilLiteral::NIL
      m = Frozone::Vm::Method.new(
        [foo], :is_a?, [:klass], [], nil, [], [], [], nil, nil, [:klass], foreign_body
      )
      foo.set_method(:is_a?, m)
      expect(pc.class_uses_canonical?(foo, :is_a?)).to be false
    end
  end

  describe '.globally_canonical?' do
    it 'is true when the captured set alone is scanned' do
      # No user overrides in the core class set → globally canonical.
      all = { Object: Frozone::Vm::Core::OBJECT_CLASS,
              Integer: Frozone::Vm::Core::INTEGER_CLASS,
              NilClass: Frozone::Vm::Core::NIL_CLASS_CLASS }
      pc::NARROWING_PREDICATES.each do |name|
        expect(pc.globally_canonical?(all, name)).to be(true), "#{name} not globally canonical"
      end
    end

    it 'is false when any class overrides the predicate with a foreign body' do
      # Build a foreign class that overrides is_a?.
      foo = Frozone::Vm::ClassObject.new(:Foo, nil, Frozone::Vm::Core::OBJECT_CLASS)
      foreign_body = Frozone::Ast::NilLiteral::NIL
      m = Frozone::Vm::Method.new(
        [foo], :is_a?, [:klass], [], nil, [], [], [], nil, nil, [:klass], foreign_body
      )
      foo.set_method(:is_a?, m)
      all = { Object: Frozone::Vm::Core::OBJECT_CLASS, Foo: foo }
      expect(pc.globally_canonical?(all, :is_a?)).to be false
      # Other predicates still globally canonical.
      expect(pc.globally_canonical?(all, :nil?)).to be true
    end

    it 'is false if the capture never ran for that name' do
      expect(pc.globally_canonical?({}, :not_a_predicate)).to be false
    end
  end

  describe '.assert_no_hard_overrides!' do
    it 'is a no-op when nothing overrides a hard predicate' do
      all = { Object: Frozone::Vm::Core::OBJECT_CLASS,
              Integer: Frozone::Vm::Core::INTEGER_CLASS,
              NilClass: Frozone::Vm::Core::NIL_CLASS_CLASS }
      expect { pc.assert_no_hard_overrides!(all) }.not_to raise_error
    end

    it 'raises OverrideError when a class overrides is_a?' do
      foo = Frozone::Vm::ClassObject.new(:Foo, nil, Frozone::Vm::Core::OBJECT_CLASS)
      foreign = Frozone::Ast::NilLiteral::NIL
      m = Frozone::Vm::Method.new(
        [foo], :is_a?, [:klass], [], nil, [], [], [], nil, nil, [:klass], foreign
      )
      foo.set_method(:is_a?, m)
      all = { Foo: foo, Object: Frozone::Vm::Core::OBJECT_CLASS }
      expect { pc.assert_no_hard_overrides!(all) }
        .to raise_error(pc::OverrideError, /Foo#is_a\?/)
    end

    it 'lists every offender in the error message' do
      foo = Frozone::Vm::ClassObject.new(:Foo, nil, Frozone::Vm::Core::OBJECT_CLASS)
      bar = Frozone::Vm::ClassObject.new(:Bar, nil, Frozone::Vm::Core::OBJECT_CLASS)
      foreign = Frozone::Ast::NilLiteral::NIL
      m_foo = Frozone::Vm::Method.new([foo], :is_a?, [:k], [], nil, [], [], [], nil, nil, [:k], foreign)
      m_bar = Frozone::Vm::Method.new([bar], :nil?, [], [], nil, [], [], [], nil, nil, [], foreign)
      foo.set_method(:is_a?, m_foo)
      bar.set_method(:nil?, m_bar)
      all = { Foo: foo, Bar: bar }
      expect { pc.assert_no_hard_overrides!(all) }.to raise_error(pc::OverrideError) do |err|
        expect(err.message).to include('Foo#is_a?')
        expect(err.message).to include('Bar#nil?')
      end
    end
  end

  describe '.override_classes' do
    it 'returns empty set when no overrides exist' do
      all = { Object: Frozone::Vm::Core::OBJECT_CLASS,
              Integer: Frozone::Vm::Core::INTEGER_CLASS }
      expect(pc.override_classes(all, :is_a?)).to be_empty
    end

    it 'collects classes with a non-canonical body' do
      foo = Frozone::Vm::ClassObject.new(:Foo, nil, Frozone::Vm::Core::OBJECT_CLASS)
      bar = Frozone::Vm::ClassObject.new(:Bar, nil, Frozone::Vm::Core::OBJECT_CLASS)
      foreign = Frozone::Ast::NilLiteral::NIL
      [foo, bar].each do |cls|
        m = Frozone::Vm::Method.new(
          [cls], :is_a?, [:klass], [], nil, [], [], [], nil, nil, [:klass], foreign
        )
        cls.set_method(:is_a?, m)
      end
      all = { Foo: foo, Bar: bar, Integer: Frozone::Vm::Core::INTEGER_CLASS }
      overrides = pc.override_classes(all, :is_a?)
      expect(overrides).to include(foo, bar)
      expect(overrides).not_to include(Frozone::Vm::Core::INTEGER_CLASS)
    end
  end
end
