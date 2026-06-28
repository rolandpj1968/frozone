# Monotone fixed-point worklist engine.
#
# Two iteration modes — both converge to the same Least Fixed Point
# for monotone lattice + monotone transfer functions. If they
# disagree on a pass, monotonicity is broken — actionable bug.
#
#   :eager
#     lookup reads the live value map. Updates from one transfer
#     call become visible to the next call in the same iteration.
#     Faster convergence on typical analyses (propagation chains
#     don't need a full round-trip each). Default.
#
#   :snapshot
#     lookup reads a frozen copy of the value map taken at the
#     start of each round. Within a round, every transfer call
#     sees the same state. Slower convergence but parallelizable
#     (round-internal calls are independent) and easier to debug
#     (per-round states are determinate).
#
# Termination relies on the lattice being finite-height OR the
# pass implementing widening (override `Lattice#widen`). Without
# either, an unbounded ascending chain will loop forever — sound
# but useless.

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
