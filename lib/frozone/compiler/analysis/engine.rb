# Monotone fixed-point worklist engine.
#
# ------------------------------------------------------------------
# Iteration modes
# ------------------------------------------------------------------
#
# Both modes converge to the same Least Fixed Point for monotone
# lattices and transfer functions. If they disagree on a pass,
# monotonicity is broken somewhere — actionable bug, not a config
# preference. The two-mode dual-check is a primary soundness tool
# during pass development.
#
#   :eager
#     The `lookup` passed to each transfer call reads the LIVE
#     value map. An update written by one transfer call is visible
#     to every subsequent call in the same iteration. Faster
#     convergence — propagation chains advance multiple steps per
#     worklist pop rather than needing a full round-trip each.
#     Default mode.
#
#   :snapshot
#     The `lookup` reads a frozen copy of the value map taken at
#     the start of each round. Every transfer call within a round
#     sees identical state. Convergence is slower but the round is
#     trivially parallelizable (round-internal calls are independent)
#     and debugging is easier (each round is a clean delta snapshot).
#
# ------------------------------------------------------------------
# Literature mapping
# ------------------------------------------------------------------
#
# These are the well-known dataflow-analysis dichotomies under
# clearer names. If you're reading textbooks (Cousot, Aho/Sethi/Ullman,
# Nielson²/Hankin) here's the bridge:
#
#   :eager    ≡ Gauss-Seidel iteration   (numerical analysis)
#             ≡ "chaotic" iteration       (abstract interpretation —
#                                          Cousot & Cousot 1977)
#             ≡ asynchronous iteration    (iterative solvers)
#
#   :snapshot ≡ Jacobi iteration          (numerical analysis)
#             ≡ "round-robin" iteration   (dataflow textbooks — but
#                                          this clashes with the OS
#                                          scheduling sense of the
#                                          term)
#             ≡ synchronous iteration     (iterative solvers)
#
# We deliberately avoid those names. "Chaotic" suggests the result
# is non-deterministic — it isn't, the LFP is unique regardless of
# schedule for monotone problems. "Round-robin" suggests rotating
# queue with timeslicing, which is also wrong. "Gauss-Seidel" and
# "Jacobi" carry the right semantics but require literature exposure.
#
# `:eager` and `:snapshot` describe *what the lookup sees* without
# inviting wrong intuitions. The cost: a reader chasing widening
# (which we don't have yet) needs this comment block to bridge to
# the literature. We pay that cost willingly.
#
# ------------------------------------------------------------------
# Termination
# ------------------------------------------------------------------
#
# Termination requires either:
#   - the lattice being finite-height (every ascending chain
#     stabilizes after finitely many joins), OR
#   - the pass implementing widening (override `Lattice#widen` to
#     accelerate convergence at the cost of precision)
#
# Phase 0 / Phase 1 analyses (reachability, NA eligibility, leaf-class,
# try-frame, visibility) are all finite-height — no widening needed.
# When TI's parametric lattice lands (Phase 3), widening becomes
# load-bearing and the literature distinctions above start to matter
# more (`:eager` + widening can lose precision schedule-dependently
# in pathological cases). Until then both modes are equivalent in
# both result and observable behavior modulo perf.

require_relative 'lattice'
require_relative 'pass'

module Frozone
  module Compiler
    module Analysis
      class Engine
        VALID_MODES = %i[eager snapshot].freeze

        attr_reader :values

        def initialize(pass, mode: :eager)
          unless VALID_MODES.include?(mode)
            raise ArgumentError,
                  "unknown iteration mode #{mode.inspect}; valid: #{VALID_MODES.inspect}"
          end
          @pass = pass
          @lattice = pass.lattice
          @mode = mode
          # Default to lattice bottom for any point we haven't reached yet.
          @values = Hash.new { @lattice.bottom }
          @worklist = []
          @on_worklist = {}
        end

        # Run to fixed point. Returns the final value map.
        def run
          @pass.seed.each { |point, value| enqueue_update(point, value) }
          case @mode
          when :eager    then run_eager
          when :snapshot then run_snapshot
          end
          @values
        end

        private

        def run_eager
          eager_lookup = ->(p) { @values[p] }
          until @worklist.empty?
            point = pop_worklist
            value = @values[point]
            @pass.transfer(point, value, eager_lookup).each do |target, contrib|
              enqueue_update(target, contrib)
            end
          end
        end

        def run_snapshot
          until @worklist.empty?
            this_round = @worklist
            @worklist = []
            @on_worklist = {}
            snapshot = @values.dup
            snapshot.default_proc = ->(_, _) { @lattice.bottom }
            snapshot_lookup = ->(p) { snapshot[p] }
            this_round.each do |point|
              value = snapshot[point]
              @pass.transfer(point, value, snapshot_lookup).each do |target, contrib|
                enqueue_update(target, contrib)
              end
            end
          end
        end

        def enqueue_update(point, new_value)
          old = @values[point]
          joined = @lattice.join(old, new_value)
          # Monotone join → joined ⊒ old. The only way subsumes?(joined, old)
          # is true is joined == old (no progress). Skip the enqueue.
          return if @lattice.subsumes?(joined, old)
          @values[point] = joined
          return if @on_worklist[point]
          @on_worklist[point] = true
          @worklist << point
        end

        def pop_worklist
          point = @worklist.shift
          @on_worklist.delete(point)
          point
        end
      end
    end
  end
end
