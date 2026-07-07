require_relative '../../../support/vm_loader'
require_relative '../../../../lib/frozone/compiler/analysis/type_lattice'

RSpec.describe Frozone::Compiler::Analysis::TypeLattice do
  # Build a small closed-world class hierarchy for the tests.
  # BasicObject → Object → Numeric → Integer
  #                                → Float
  #                     → Comparable-tagged (skipped as module)
  #                     → String
  #                     → TrueClass
  #                     → FalseClass
  #                     → NilClass
  #                     → Foo → Bar
  #                     → Zap  (isolated user class under Object)
  def make_hierarchy
    vm = Frozone::Vm

    # Root: BasicObject, superclass nil.
    basic = vm::ClassObject.new(:BasicObject, nil, nil)
    object = vm::ClassObject.new(:Object, nil, basic)
    numeric = vm::ClassObject.new(:Numeric, nil, object)
    integer = vm::ClassObject.new(:Integer, nil, numeric)
    float = vm::ClassObject.new(:Float, nil, numeric)
    string = vm::ClassObject.new(:String, nil, object)
    true_c = vm::ClassObject.new(:TrueClass, nil, object)
    false_c = vm::ClassObject.new(:FalseClass, nil, object)
    nil_c = vm::ClassObject.new(:NilClass, nil, object)
    foo = vm::ClassObject.new(:Foo, nil, object)
    bar = vm::ClassObject.new(:Bar, nil, foo)
    zap = vm::ClassObject.new(:Zap, nil, object)

    # Also a plain module — should NOT contribute to type LUBs.
    comparable = vm::ModuleObject.new(:Comparable, nil)

    {
      BasicObject: basic, Object: object, Numeric: numeric,
      Integer:    integer, Float:    float,
      String:     string,
      TrueClass:  true_c, FalseClass: false_c, NilClass: nil_c,
      Foo:        foo, Bar: bar, Zap: zap,
      Comparable: comparable
    }
  end

  let(:all_classes) { make_hierarchy }
  let(:lattice)     { described_class.new(all_classes) }

  # Sugar for building Type values in tests.
  def t(c, nullable: false) = lattice.concrete(c, nullable: nullable)
  def bot = lattice.bottom
  def top = lattice.top
  def boolean(nullable: false) = lattice.boolean_type(nullable: nullable)

  describe '#bottom / #top' do
    it 'returns the same instance every time (identity-cheap)' do
      expect(lattice.bottom).to equal(lattice.bottom)
      expect(lattice.top).to equal(lattice.top)
    end

    it 'has readable to_s' do
      expect(lattice.bottom.to_s).to eq('⊥')
      expect(lattice.top.to_s).to eq('⊤')
    end
  end

  describe 'ancestor chain precompute' do
    it 'walks superclass links, excludes modules' do
      chains = lattice.ancestor_chains
      expect(chains[:Integer]).to eq(%i[Integer Numeric Object BasicObject])
      expect(chains[:Bar]).to     eq(%i[Bar Foo Object BasicObject])
      expect(chains[:BasicObject]).to eq(%i[BasicObject])
      # Module has no chain entry — Comparable never appears
      expect(chains).not_to have_key(:Comparable)
    end
  end

  describe '#class_lub — the raw class-hierarchy join' do
    it 'is identity on equal inputs' do
      expect(lattice.class_lub(:Integer, :Integer)).to eq(:Integer)
    end

    it 'finds the deepest shared class ancestor' do
      expect(lattice.class_lub(:Integer, :Float)).to eq(:Numeric)
      expect(lattice.class_lub(:Integer, :String)).to eq(:Object)
      expect(lattice.class_lub(:Bar, :Foo)).to eq(:Foo)
      expect(lattice.class_lub(:Bar, :Zap)).to eq(:Object)
    end

    it 'is symmetric' do
      expect(lattice.class_lub(:Integer, :Float)).to eq(lattice.class_lub(:Float, :Integer))
      expect(lattice.class_lub(:Bar, :Zap)).to eq(lattice.class_lub(:Zap, :Bar))
    end

    it 'falls back to BasicObject when either side is unknown' do
      expect(lattice.class_lub(:Integer, :NotAClass)).to eq(:BasicObject)
    end

    it 'is memoised (same result on repeated call)' do
      r1 = lattice.class_lub(:Integer, :Float)
      r2 = lattice.class_lub(:Integer, :Float)
      expect(r1).to eq(r2)
    end
  end

  describe '#join — the lattice-level join' do
    it '⊥ is identity' do
      expect(lattice.join(bot, t(:Integer))).to eq(t(:Integer))
      expect(lattice.join(t(:Integer), bot)).to eq(t(:Integer))
      expect(lattice.join(bot, bot)).to eq(bot)
    end

    it '⊤ absorbs (⊤ ∨ X = ⊤)' do
      expect(lattice.join(top, t(:Integer))).to eq(top)
      expect(lattice.join(t(:String), top)).to eq(top)
    end

    it 'is idempotent (X ∨ X = X) for concrete types' do
      expect(lattice.join(t(:Integer), t(:Integer))).to eq(t(:Integer))
      expect(lattice.join(t(:Bar), t(:Bar))).to eq(t(:Bar))
    end

    it 'joins concrete classes via class-hierarchy LUB' do
      expect(lattice.join(t(:Integer), t(:Float))).to eq(t(:Numeric))
      expect(lattice.join(t(:Integer), t(:String))).to eq(t(:Object))
      expect(lattice.join(t(:Bar), t(:Foo))).to eq(t(:Foo))
    end

    it 'is symmetric on concrete-class inputs' do
      expect(lattice.join(t(:Integer), t(:Float))).to eq(lattice.join(t(:Float), t(:Integer)))
    end

    describe '<boolean> carve-out' do
      it 'joins TrueClass ∨ FalseClass into <boolean>' do
        expect(lattice.join(t(:TrueClass), t(:FalseClass))).to eq(boolean)
      end

      it '<boolean> absorbs TrueClass / FalseClass' do
        expect(lattice.join(boolean, t(:TrueClass))).to eq(boolean)
        expect(lattice.join(t(:FalseClass), boolean)).to eq(boolean)
      end

      it '<boolean> ∨ non-boolean widens to Object' do
        expect(lattice.join(boolean, t(:Integer))).to eq(t(:Object))
        expect(lattice.join(t(:String), boolean)).to eq(t(:Object))
      end

      it 'TrueClass ∨ Integer widens to Object (does not stay <boolean>)' do
        expect(lattice.join(t(:TrueClass), t(:Integer))).to eq(t(:Object))
      end

      it '<boolean> to_s is readable' do
        expect(boolean.to_s).to eq('<boolean>')
      end
    end

    describe 'nullable dimension' do
      it 'joining with NilClass sets nullable on the other side' do
        result = lattice.join(t(:Integer), t(:NilClass))
        expect(result).to eq(t(:Integer, nullable: true))
      end

      it 'NilClass ∨ NilClass stays NilClass (not-nullable — the class itself)' do
        expect(lattice.join(t(:NilClass), t(:NilClass))).to eq(t(:NilClass))
      end

      it 'nullable OR nullable stays nullable' do
        result = lattice.join(t(:Integer, nullable: true), t(:Integer, nullable: true))
        expect(result).to eq(t(:Integer, nullable: true))
      end

      it 'nullable ∨ non-nullable becomes nullable' do
        result = lattice.join(t(:Integer, nullable: true), t(:Integer, nullable: false))
        expect(result).to eq(t(:Integer, nullable: true))
      end

      it 'joining nullable+different classes carries nullability through the LUB' do
        result = lattice.join(t(:Integer, nullable: true), t(:Float))
        expect(result).to eq(t(:Numeric, nullable: true))
      end

      it 'joining boolean with NilClass produces nullable boolean' do
        expect(lattice.join(boolean, t(:NilClass))).to eq(boolean(nullable: true))
      end

      it 'nullable to_s ends with ?' do
        expect(t(:Integer, nullable: true).to_s).to eq('Integer?')
      end
    end
  end

  describe '#subsumes?  (a ⊑ b)' do
    it '⊥ ⊑ everything, everything ⊑ ⊤' do
      expect(lattice.subsumes?(bot, t(:Integer))).to be true
      expect(lattice.subsumes?(t(:Integer), top)).to be true
      expect(lattice.subsumes?(bot, top)).to be true
    end

    it 'reflexive: X ⊑ X' do
      expect(lattice.subsumes?(t(:Integer), t(:Integer))).to be true
      expect(lattice.subsumes?(boolean, boolean)).to be true
    end

    it 'class ⊑ superclass' do
      expect(lattice.subsumes?(t(:Integer), t(:Numeric))).to be true
      expect(lattice.subsumes?(t(:Integer), t(:Object))).to be true
      expect(lattice.subsumes?(t(:Bar), t(:Foo))).to be true
    end

    it 'unrelated classes do NOT subsume each other' do
      expect(lattice.subsumes?(t(:Integer), t(:String))).to be false
      expect(lattice.subsumes?(t(:Foo), t(:Zap))).to be false
    end

    it '<boolean> ⊑ Object but not the reverse' do
      expect(lattice.subsumes?(boolean, t(:Object))).to be true
      expect(lattice.subsumes?(t(:Object), boolean)).to be false
    end

    it 'TrueClass / FalseClass ⊑ <boolean>' do
      expect(lattice.subsumes?(t(:TrueClass), boolean)).to be true
      expect(lattice.subsumes?(t(:FalseClass), boolean)).to be true
    end

    it 'nullable subsumption: not-nullable ⊑ nullable, not vice versa' do
      expect(lattice.subsumes?(t(:Integer, nullable: false), t(:Integer, nullable: true))).to be true
      expect(lattice.subsumes?(t(:Integer, nullable: true), t(:Integer, nullable: false))).to be false
    end
  end

  describe 'Lattice protocol compliance' do
    it 'includes the Lattice mixin' do
      expect(lattice).to be_a(Frozone::Compiler::Analysis::Lattice)
    end

    it 'widen defaults to curr (no widening)' do
      expect(lattice.widen(t(:Integer), t(:Float))).to eq(t(:Float))
    end
  end

  describe 'NORETURN — provably-diverges lattice element' do
    it 'is exposed via lattice.noreturn' do
      expect(lattice.noreturn.noreturn?).to be true
      expect(lattice.noreturn.divergent?).to be true
      # bottom is also divergent but a distinct element.
      expect(lattice.bottom.divergent?).to be true
      expect(lattice.bottom.noreturn?).to be false
    end

    it 'LUB(NORETURN, x) = x for every non-BOTTOM x' do
      %i[Integer String NilClass].each do |c|
        expect(lattice.join(lattice.noreturn, t(c))).to eq(t(c))
        expect(lattice.join(t(c), lattice.noreturn)).to eq(t(c))
      end
      expect(lattice.join(lattice.noreturn, lattice.top)).to eq(lattice.top)
    end

    it 'LUB(NORETURN, BOTTOM) = NORETURN (NORETURN is strictly above BOTTOM)' do
      expect(lattice.join(lattice.noreturn, lattice.bottom)).to eq(lattice.noreturn)
      expect(lattice.join(lattice.bottom, lattice.noreturn)).to eq(lattice.noreturn)
    end

    it 'NORETURN ⊑ every non-BOTTOM type; BOTTOM ⊑ NORETURN; NORETURN NOT ⊑ BOTTOM' do
      %i[Integer String Object].each do |c|
        expect(lattice.subsumes?(lattice.noreturn, t(c))).to be true
      end
      expect(lattice.subsumes?(lattice.noreturn, lattice.top)).to be true
      expect(lattice.subsumes?(lattice.bottom, lattice.noreturn)).to be true
      # NORETURN is a stronger positive statement than BOTTOM, so
      # NORETURN NOT ⊑ BOTTOM. This is what lets apply_update recognise
      # the BOTTOM → NORETURN transition as progress.
      expect(lattice.subsumes?(lattice.noreturn, lattice.bottom)).to be false
    end

    it 'concrete factory returns NORETURN for :__noreturn__' do
      expect(lattice.concrete(:__noreturn__)).to eq(lattice.noreturn)
    end

    it 'renders as "noreturn"' do
      expect(lattice.noreturn.to_s).to eq('noreturn')
    end
  end
end
