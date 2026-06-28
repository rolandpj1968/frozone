# Lattice protocol — the algebraic structure each analysis carries.
#
# Implementations must satisfy:
#
#   bottom ⊑ x ⊑ top   for all x
#   join(a, b) = a ⊔ b — least upper bound, monotone in both args
#   subsumes?(a, b)    — a ⊑ b
#
# Monotonicity of join (and of the pass's transfer function) is the
# soundness contract. Without it, the engine's fixed point isn't
# unique and `:eager` vs `:snapshot` may disagree. (We use that
# disagreement as a soundness check during pass development.)
#
# `widen(prev, curr)` defaults to `curr` (no widening). Override on
# lattices with ascending chains that don't terminate under join
# alone — typically infinite-height lattices like parametric types
# (`Array<T>` can grow indefinitely without ∇).

module Frozone
  module Compiler
    module Analysis
      module Lattice
        def bottom = raise NotImplementedError, "#{self.class}#bottom"
        def top = raise NotImplementedError, "#{self.class}#top"
        def join(_a, _b) = raise NotImplementedError, "#{self.class}#join"
        def subsumes?(_a, _b) = raise NotImplementedError, "#{self.class}#subsumes?"
        def widen(_prev, curr) = curr
      end

      # The cheapest non-trivial lattice — only two values. Useful for
      # reachability / membership analyses (Reachable/Unreachable,
      # Eligible/NotEligible, Leaf/NonLeaf, …) where each program point
      # is either "in the set" or "not in the set".
      class TwoValueLattice
        include Lattice
        def initialize(bottom_value:, top_value:)
          @bot = bottom_value
          @top = top_value
        end

        def bottom = @bot
        def top = @top
        def join(a, b) = (a == @top || b == @top) ? @top : @bot
        def subsumes?(a, b) = (a == @bot) || (b == @top)
      end
    end
  end
end
