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

require 'set'
require_relative 'lattice'
require_relative 'pass'
require_relative 'transfer_result'

module Frozone
  module Compiler
    module Analysis
      class Engine
        VALID_MODES = %i[eager snapshot].freeze

        # values         — Hash[Node → LatticeValue], final result
        # rounds         — outer-loop iterations executed
        #                  :eager    — 1 (or 0 if seed was empty); the
        #                              worklist drains in a single sweep
        #                              that's the whole point of eager
        #                  :snapshot — propagation depth (one round per
        #                              "layer" of the call graph)
        # transfer_calls — total #pass.transfer invocations. Same for
        #                  both modes on the same input. The ratio
        #                  (transfer_calls / rounds) is the average
        #                  per-round work, a useful diagnostic.
        attr_reader :values, :rounds, :transfer_calls, :deps

        def initialize(pass, mode: :eager)
          unless VALID_MODES.include?(mode)
            raise ArgumentError,
                  "unknown iteration mode #{mode.inspect}; valid: #{VALID_MODES.inspect}"
          end
          @pass = pass
          @lattice = pass.lattice
          @mode = mode
          # Default to lattice bottom for any node we haven't reached yet.
          @values = Hash.new { @lattice.bottom }
          # Insertion-ordered, deduplicating FIFO. Set's `<<` is
          # idempotent so we get free dedup; insertion order gives
          # FIFO when we iterate. Replaces an Array + on_worklist
          # Hash combo with one stdlib structure.
          @worklist = Set.new
          # Dep map: `target_node → Set[dependent_nodes]`. Populated
          # every time a transfer calls `lookup.call(target_node)` —
          # the dependent is the node currently being transferred.
          # When `apply_update` raises `target_node`, every dependent
          # is re-enqueued so their transfers re-read with the new
          # value. Without this the fixpoint is order-dependent:
          # transfers that ran BEFORE their callee's return-value
          # rose don't see the updated value, so their result stays
          # stale unless something else happens to re-enqueue them.
          @deps = Hash.new { |h, k| h[k] = Set.new }
          # Nodes whose value rose during the current round. Used by
          # snapshot mode's end-of-round sweep — see `sweep_rose_deps`.
          @rose_this_round = Set.new
          @rounds = 0
          @transfer_calls = 0
        end

        # Run to fixed point. Returns the final value map.
        #
        # The two modes are unified around `process_round`: both modes
        # process the current worklist via `process_round`, parameterized
        # on the (source, target) value-map pair.
        #
        #   :eager    — source == target == @values. Reads and writes the
        #               LIVE map; updates propagate within the drain.
        #               One continuous drain = one round.
        #   :snapshot — source = @values (frozen); target = new_values.
        #               Reads see previous-round state; writes accumulate
        #               into a fresh map that becomes @values at round end.
        #               One round = one process_round call.
        def run
          # Seed lands directly into @values — there's no "previous round"
          # yet, so the eager/snapshot distinction is moot for the seed.
          # Every seeded node is always enqueued for the first-round
          # transfer, regardless of whether its seed value grows past
          # the default. This matters for passes whose transfer LEARNS
          # the value (TI: start at ⊥, transfer walks the body, joins
          # up); a bottom-valued seed still needs to be visited once so
          # the transfer runs.
          @pass.seed.each do |node, value|
            apply_update(node, value, into: @values)
            @worklist << node
          end
          case @mode
          when :eager    then drain_eager
          when :snapshot then drain_snapshot
          end
          @values
        end

        private

        # Eager: one round conceptually (a single continuous drain),
        # though process_round may be called multiple times as the
        # worklist grows during processing.
        def drain_eager
          return if @worklist.empty?
          @rounds = 1
          until @worklist.empty?
            process_round(source: @values, target: @values)
          end
        end

        # Snapshot (functional Jacobi):
        #   - @values is the previous round's state — untouched during the
        #     round, every transfer call reads from it via the lookup.
        #   - new_values starts as a copy of @values and accumulates
        #     this round's contributions.
        #   - At round end, @values is atomically replaced by new_values.
        # Each process_round call is one round of propagation depth.
        def drain_snapshot
          until @worklist.empty?
            @rounds += 1
            new_values = @values.dup
            new_values.default_proc = ->(_, _) { @lattice.bottom }
            @rose_this_round.clear
            process_round(source: @values, target: new_values)
            @values = new_values
            # End-of-round sweep. Snapshot's Achilles heel: within a
            # round, dependent Y might record its dep on target X only
            # AFTER X's apply_update ran, so X's write never enqueued Y.
            # Since deps accumulate persistently across rounds, Y's dep
            # IS now on record — enqueue anything that reads a node
            # that rose this round. Eager doesn't need this: writes are
            # visible immediately to same-round readers via source == @values.
            sweep_rose_deps
          end
        end

        # Re-enqueue every recorded dependent of a node that rose in
        # this round. Cheap — one set-merge per rose node, bounded by
        # the total dep-graph size which is finite.
        def sweep_rose_deps
          @rose_this_round.each do |node|
            deps = @deps[node]
            @worklist.merge(deps) if deps && !deps.empty?
          end
        end

        # Drain the current worklist, calling pass.transfer for each
        # enqueued node. Reads (lookup + the `value` arg to transfer)
        # come from `source`; writes (via apply_transfer_result) go to
        # `target`. The same logic serves both modes; the (source,
        # target) parameterization is where the modes differ.
        def process_round(source:, target:)
          batch = @worklist
          @worklist = Set.new
          batch.each do |node|
            # Wrap lookup per iteration so it captures THIS node as
            # the current dependent. Every `lookup.call(target)` from
            # inside pass.transfer records `target → node` in @deps —
            # when `target`'s value later rises, apply_update re-enqueues
            # `node` for another transfer.
            # Explicit local rebind — Ruby's block-parameter scope
            # can share the outer `node` binding across iterations of
            # certain iterators, so closures over the block param see
            # the LAST iteration's value instead of their own. Copying
            # to `current_node` forces a fresh local per iteration.
            current_node = node
            lookup = ->(n) {
              @deps[n] << current_node
              source[n]
            }
            value = source[node]
            @transfer_calls += 1
            result = @pass.transfer(node, value, lookup)
            apply_transfer_result(node, result, into: target)
          end
        end

        # Apply a TransferResult: the self-update (pull side) lands on
        # the visited node; each push lands on its target. Both routes
        # go through apply_update for the monotone-join clamp.
        def apply_transfer_result(node, result, into:)
          if result.self_value
            apply_update(node, result.self_value, into: into)
          end
          result.pushes.each do |target, contrib|
            apply_update(target, contrib, into: into)
          end
        end

        # Monotone update + enqueue. The same logic applies to both
        # modes; only the `into:` target differs:
        #   :eager    — write into @values (live map, updates visible
        #               immediately to subsequent reads).
        #   :snapshot — write into `new_values` (the next round's map,
        #               flipped to @values only at round end).
        # The framework enforces monotonicity at the storage level via
        # the `join(old, new_value)` clamp here: stored values can only
        # ascend, regardless of what the pass returns.
        def apply_update(node, new_value, into:)
          old = into[node]
          joined = @lattice.join(old, new_value)
          # Monotone join → joined ⊒ old. The only way subsumes?(joined, old)
          # is true is joined == old (no progress). Skip the enqueue.
          return if @lattice.subsumes?(joined, old)
          into[node] = joined
          # Set's << is idempotent — no need to check for membership.
          @worklist << node
          # Cross-node dep propagation: every transfer that READ this
          # node (recorded via the wrapped lookup in process_round)
          # must re-run so it can see the new value. Without this the
          # fixpoint is order-dependent and both engine modes reach
          # different local approximations (task #248).
          deps = @deps[node]
          @worklist.merge(deps) if deps && !deps.empty?
          # Also note it as "rose this round" so snapshot's end-of-round
          # sweep re-enqueues deps recorded LATER in the same round.
          # Harmless in eager mode (@rose_this_round isn't consulted).
          @rose_this_round << node
        end
      end
    end
  end
end
