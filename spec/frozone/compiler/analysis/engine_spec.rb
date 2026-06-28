require 'set'
require_relative '../../../../lib/frozone/compiler/analysis/engine'

# Synthetic pass used to exercise the engine without depending on
# any real compiler analysis. The graph is a tiny digraph; the
# pass propagates "is this node reachable from the seed?" facts.
class TestReachabilityPass < Frozone::Compiler::Analysis::Pass
  def initialize(edges:, seeds:)
    @edges = edges  # Hash[Node → Array[Node]]
    @seeds = seeds  # Array[Node]
    @lattice = Frozone::Compiler::Analysis::TwoValueLattice.new(
      bottom_value: :unreachable,
      top_value:    :reachable,
    )
  end

  def lattice = @lattice
  def seed = @seeds.each_with_object({}) { |s, h| h[s] = :reachable }

  def transfer(node, value, _lookup)
    return {} unless value == :reachable
    targets = @edges[node] || []
    targets.each_with_object({}) { |t, h| h[t] = :reachable }
  end
end

RSpec.describe Frozone::Compiler::Analysis::Engine do
  let(:edges) do
    {
      :a => %i[b c],
      :b => %i[d],
      :c => %i[e f],
      :e => %i[a],          # cycle a -> c -> e -> a — must terminate
      :g => %i[h],          # disconnected
    }
  end
  let(:pass) { TestReachabilityPass.new(edges: edges, seeds: [:a]) }

  describe 'eager mode' do
    it 'reaches all forward-transitive nodes and ignores unreachable subgraph' do
      values = described_class.new(pass, mode: :eager).run
      reachable = values.select { |_, v| v == :reachable }.keys.to_set
      expect(reachable).to eq(Set[:a, :b, :c, :d, :e, :f])
      expect(values[:g]).to eq(:unreachable)
      expect(values[:h]).to eq(:unreachable)
    end

    it 'terminates on cycles' do
      # The cycle a → c → e → a must be detected via the subsumes? check
      # in apply_update (no progress → skip re-enqueue).
      expect { described_class.new(pass, mode: :eager).run }.not_to raise_error
    end
  end

  describe 'snapshot mode' do
    it 'converges to the same LFP as eager' do
      eager_vals    = described_class.new(pass, mode: :eager).run
      snapshot_vals = described_class.new(pass, mode: :snapshot).run
      # Both modes must produce identical maps for monotone passes.
      # Disagreement signals broken monotonicity (a real soundness bug).
      expect(snapshot_vals.to_h).to eq(eager_vals.to_h)
    end
  end

  describe 'mode validation' do
    it 'rejects unknown modes' do
      expect { described_class.new(pass, mode: :random) }.to raise_error(ArgumentError, /unknown iteration mode/)
    end
  end

  describe 'empty seed' do
    it 'returns an empty value map' do
      empty_pass = TestReachabilityPass.new(edges: edges, seeds: [])
      engine = described_class.new(empty_pass)
      values = engine.run
      expect(values.to_h).to eq({})
      # Lookups still return bottom for unseen nodes.
      expect(values[:a]).to eq(:unreachable)
      expect(engine.rounds).to eq(0)
      expect(engine.transfer_calls).to eq(0)
    end
  end

  describe 'convergence speed (rounds vs transfer_calls)' do
    # A single chain a → b → c → d → e exposes the fundamental
    # distinction: eager drains the whole chain in one round;
    # snapshot needs one round per propagation step. transfer_calls
    # is identical (every reachable node gets transferred exactly
    # once in both modes — the work is the same).
    let(:chain_pass) do
      TestReachabilityPass.new(
        edges: { a: [:b], b: [:c], c: [:d], d: [:e] },
        seeds: [:a],
      )
    end

    it 'eager converges in 1 round, regardless of chain depth' do
      engine = described_class.new(chain_pass, mode: :eager)
      engine.run
      expect(engine.rounds).to eq(1)
      expect(engine.transfer_calls).to eq(5)  # a, b, c, d, e
    end

    it 'snapshot needs one round per propagation step' do
      engine = described_class.new(chain_pass, mode: :snapshot)
      engine.run
      expect(engine.rounds).to eq(5)           # one round drains one chain step
      expect(engine.transfer_calls).to eq(5)   # same total work as eager
    end

    # Two parallel chains a→b→c and d→e→f with seeds [a, d] make
    # the parallelism visible: snapshot processes a and d in round 1
    # (so round 2 has b and e together), totaling 3 rounds for 6
    # transfer calls — average 2 transfers per round. Eager still
    # 1 round, 6 calls.
    it 'snapshot exposes parallelism on independent chains' do
      parallel_pass = TestReachabilityPass.new(
        edges: { a: [:b], b: [:c], d: [:e], e: [:f] },
        seeds: %i[a d],
      )
      eager_engine    = described_class.new(parallel_pass, mode: :eager).tap(&:run)
      snapshot_engine = described_class.new(parallel_pass, mode: :snapshot).tap(&:run)

      expect(eager_engine.rounds).to eq(1)
      expect(eager_engine.transfer_calls).to eq(6)

      expect(snapshot_engine.rounds).to eq(3)            # depth of each chain
      expect(snapshot_engine.transfer_calls).to eq(6)    # same total work
    end
  end
end
