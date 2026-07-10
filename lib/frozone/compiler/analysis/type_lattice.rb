# Type lattice for Tier-1 TI: concrete-class-only, flow-insensitive
# ("0-CFA over the class hierarchy"). Values are `Type(concrete,
# nullable)` where:
#
#   concrete ∈ { :__bottom__, :__top__, :__boolean__, ClassSymbol }
#     - :__bottom__ — uncomputed / unreached (join identity).
#     - :__top__    — BasicObject-equivalent "unknown"; the escape
#                     hatch when narrowing fails.
#     - :__boolean__ — synthetic union of TrueClass | FalseClass. Not
#                     a real Ruby class; carved out because predicate
#                     returns are common enough to warrant a level
#                     between the two constituents and Object.
#     - ClassSymbol — a specific class's flat-name Symbol
#                     (e.g. :Integer, :Frozone_Vm_ObjectObject).
#
#   nullable ∈ { true, false } — orthogonal bit; true means Nil is
#                                a possible runtime value in addition
#                                to `concrete`.
#
# Join is the class-hierarchy LUB (least upper bound). Ruby is
# single-inheritance for classes, so every pair has a unique deepest
# common ancestor. Modules are ignored — module_flattening.rb has
# materialised every included module's methods into each including
# class's own method table before TI runs, so module identity is
# invisible at this layer. If a pair has no shared class ancestor
# other than the root, join yields :BasicObject.
#
# The class hierarchy is closed-world so we precompute each class's
# ancestor chain once at pass init. LUB queries are cache-memoised
# on canonicalised pairs.

require 'set'
require_relative 'lattice'
require_relative '../reachability'
require_relative '../../vm/class_object'
require_relative '../../vm/module_object'

module Frozone
  module Compiler
    module Analysis
      class TypeLattice
        include Lattice

        # A Type value in the lattice. Frozen at construction to
        # keep `==` cheap (Struct falls back to field-eq) and to
        # make caching sound (map keys never mutate under us).
        Type = Struct.new(:concrete, :nullable) do
          def bottom?   = concrete == :__bottom__
          def top?      = concrete == :__top__
          def noreturn? = concrete == :__noreturn__
          def boolean_synth? = concrete == :__boolean__

          # NORETURN and BOTTOM are BOTH join-identity, but the two
          # convey different facts:
          #   BOTTOM   — "no data yet; may rise as the fixpoint runs"
          #   NORETURN — "provably always diverges" (raise / throw /
          #              exit / infinite loop) — a positive statement.
          # For lattice math they behave the same; consumers that care
          # about the distinction check `.noreturn?` explicitly.
          def divergent? = bottom? || noreturn?

          def to_s
            base = case concrete
                   when :__bottom__   then '⊥'
                   when :__top__      then '⊤'
                   when :__boolean__  then '<boolean>'
                   when :__noreturn__ then 'noreturn'
                   else concrete.to_s
                   end
            nullable ? "#{base}?" : base
          end
          alias_method :inspect, :to_s
        end

        BOTTOM           = Type.new(:__bottom__,   false).freeze
        TOP              = Type.new(:__top__,      false).freeze
        # ⊤? == ⊤ (nil is a member of the ⊤ universe); alias for
        # backwards-compat with callers that construct explicit
        # nullable TOPs. join() and factories collapse to TOP.
        TOP_NULLABLE     = TOP
        BOOLEAN          = Type.new(:__boolean__,  false).freeze
        BOOLEAN_NULLABLE = Type.new(:__boolean__,  true).freeze
        NORETURN         = Type.new(:__noreturn__, false).freeze

        BOOLEAN_CLASSES = [:TrueClass, :FalseClass].freeze
        NIL_CLASS       = :NilClass

        # Concrete classes for which `T?` is set-theoretically identical
        # to `T` because NilClass ⊑ T. Nullable adds no information; the
        # `?` bit is normalized away at construction time. Under the
        # Frozone hierarchy NilClass < Object < BasicObject, and ⊤ is
        # BasicObject-equivalent, so the set is fixed at four elements.
        NIL_SUPERTYPES = %i[NilClass Object BasicObject __top__].freeze
        private_constant :NIL_SUPERTYPES

        attr_reader :ancestor_chains, :descendants, :all_classes

        # `all_classes` — Hash(flat_name Symbol → Vm::ClassObject/ModuleObject)
        # produced by the emitter. Only entries whose value is a
        # ClassObject contribute to the ancestor chain walk. Module
        # entries are silently ignored (they can't be types at Tier 1).
        def initialize(all_classes)
          @all_classes = all_classes
          @ancestor_chains = precompute_ancestor_chains
          @descendants = precompute_descendants
          @lub_cache = {}
        end

        # Lattice interface --------------------------------------------

        def bottom = BOTTOM
        def top    = TOP

        def join(a, b)
          # ⊥ is join-identity: BOTTOM ⊑ every element, so LUB(⊥, x) = x.
          return b if a.bottom?
          return a if b.bottom?
          # NORETURN sits strictly above BOTTOM but below every real
          # (potentially-inhabited) type. LUB(NORETURN, x) = x for any
          # non-bottom x. Ordering: BOTTOM ⊑ NORETURN ⊑ everything-else.
          return b if a.noreturn?
          return a if b.noreturn?

          nullable = a.nullable || b.nullable

          # ⊤ absorbs everything. Nullable bit is meaningless on ⊤
          # (NilClass ⊑ ⊤ set-theoretically), so it's dropped.
          return TOP if a.top? || b.top?

          # NilClass narrows away — the null-ness moves onto the
          # `nullable` bit and the concrete becomes the OTHER side
          # (or NilClass itself if both are NilClass).
          if a.concrete == NIL_CLASS && b.concrete == NIL_CLASS
            return a
          end
          if a.concrete == NIL_CLASS
            return b.nullable ? b : make(b.concrete, true)
          end
          if b.concrete == NIL_CLASS
            return a.nullable ? a : make(a.concrete, true)
          end

          # Same concrete → merge nullable only
          if a.concrete == b.concrete
            return a.nullable == b.nullable ? a : make(a.concrete, true)
          end

          # Boolean carve-out: TrueClass ∨ FalseClass ∨ <boolean> stay
          # inside <boolean>; joined with anything else = LUB with Object.
          if boolean_element?(a) || boolean_element?(b)
            return boolean_join(a, b, nullable)
          end

          # Concrete class + concrete class → LUB in the class hierarchy.
          make(class_lub(a.concrete, b.concrete), nullable)
        end

        # `a ⊑ b` — a is at or below b in the lattice.
        # Ordering: BOTTOM ⊑ NORETURN ⊑ every real type ⊑ TOP.
        def subsumes?(a, b)
          # BOTTOM is below everything.
          return true if a.bottom?
          # NORETURN is below every non-BOTTOM element.
          return !b.bottom? if a.noreturn?
          # a is a real (or TOP) type. It's not ⊑ BOTTOM or NORETURN.
          return false if b.bottom? || b.noreturn?
          return true if b.top?
          return false if a.top?
          # Nullable dimension: a.nullable ⇒ b.nullable
          return false if a.nullable && !b.nullable
          return true if a.concrete == b.concrete

          # Boolean: <boolean> ⊑ Object only; TrueClass/FalseClass ⊑ <boolean>
          if a.concrete == :__boolean__
            return %i[Object BasicObject].include?(b.concrete)
          end
          if b.concrete == :__boolean__
            return BOOLEAN_CLASSES.include?(a.concrete)
          end

          # Class hierarchy: b appears in a's ancestor chain iff a ⊑ b.
          chain = @ancestor_chains[a.concrete]
          chain && chain.include?(b.concrete)
        end

        # Public constructors -----------------------------------------

        def concrete(class_sym, nullable: false)
          return BOTTOM if class_sym == :__bottom__
          return NORETURN if class_sym == :__noreturn__
          return TOP if class_sym == :__top__
          return nullable ? BOOLEAN_NULLABLE : BOOLEAN if class_sym == :__boolean__
          make(class_sym, nullable)
        end

        def noreturn = NORETURN

        def nil_type = concrete(NIL_CLASS)

        def boolean_type(nullable: false)
          nullable ? BOOLEAN_NULLABLE : BOOLEAN
        end

        # Class-hierarchy LUB primitive. Exposed for tests + for
        # transfers that want to reason about class LUBs directly
        # without wrapping in Type first.
        def class_lub(a_sym, b_sym)
          return a_sym if a_sym == b_sym
          key = a_sym.to_s < b_sym.to_s ? [a_sym, b_sym].freeze : [b_sym, a_sym].freeze
          @lub_cache[key] ||= compute_class_lub(a_sym, b_sym)
        end

        private

        # Canonicalizing Type factory. Whenever `nullable` is requested
        # for a class C where NilClass ⊑ C, the nullable bit is dropped
        # because C already includes nil in its extension. Keeps the
        # lattice's canonical form thin — every Type value has a unique
        # representation regardless of how it was constructed.
        def make(class_sym, nullable)
          nullable = false if nullable && NIL_SUPERTYPES.include?(class_sym)
          Type.new(class_sym, nullable).freeze
        end

        def boolean_element?(t)
          t.concrete == :__boolean__ || BOOLEAN_CLASSES.include?(t.concrete)
        end

        def boolean_join(a, b, nullable)
          a_bool = boolean_element?(a)
          b_bool = boolean_element?(b)
          # Both in the boolean carve-out
          if a_bool && b_bool
            return nullable ? BOOLEAN_NULLABLE : BOOLEAN
          end
          # One boolean, one not — widen to LUB(non_bool.concrete, Object).
          # TrueClass and FalseClass both descend from Object in MRI,
          # so the meet-point is Object (or higher if non_bool's chain
          # doesn't reach Object, which shouldn't happen).
          non_bool = a_bool ? b : a
          Type.new(class_lub(:Object, non_bool.concrete), nullable).freeze
        end

        def compute_class_lub(a, b)
          a_chain = @ancestor_chains[a]
          b_chain = @ancestor_chains[b]
          return :BasicObject unless a_chain && b_chain
          b_set = b_chain.to_set
          a_chain.each { |cls| return cls if b_set.include?(cls) }
          :BasicObject
        end

        # For every ClassObject in @all_classes, walk `.superclass`
        # until nil and record the flat-name chain. Modules and other
        # non-class entries are skipped (they can't participate in TI
        # types — module_flattening has already lowered their methods
        # into each including class's own vtable).
        def precompute_ancestor_chains
          chains = {}
          @all_classes.each do |flat, cls|
            next unless cls.is_a?(Vm::ClassObject)
            chains[flat] = build_chain(cls).freeze
          end
          chains.freeze
        end

        def build_chain(cls)
          chain = []
          current = cls
          while current.is_a?(Vm::ClassObject)
            flat = Reachability.flat_name(current)
            chain << flat if flat
            current = current.superclass
          end
          chain
        end

        # Invert `ancestor_chains` into a "descendants of X" map. For
        # every class D and every ancestor A in D's chain, D is a
        # descendant of A. The class itself is INCLUDED in its own
        # descendant set (self ⊑ self) so type-cone consumers can
        # just iterate `descendants[T]` and get T + all subclasses.
        # Frozen at build time so consumers can hash-key it safely.
        def precompute_descendants
          descs = Hash.new { |h, k| h[k] = Set.new }
          @ancestor_chains.each do |d, chain|
            chain.each { |a| descs[a] << d }
          end
          # Drop the default proc — reading unknown classes on the
          # frozen map must return nil, not fire the block and try
          # to mutate a frozen hash. Consumers explicitly handle
          # the nil case (fallback to a single-element cone).
          descs.default_proc = nil
          descs.each_value(&:freeze)
          descs.freeze
        end
      end
    end
  end
end
