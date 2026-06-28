require 'set'
require_relative '../../../../lib/frozone/compiler/analysis/engine'

# Synthetic pass used to exercise the engine without depending on
# any real compiler analysis. The graph is a tiny digraph; the
# pass propagates "is this point reachable from the seed?" facts.
class TestReachabilityPass < Frozone::Compiler::Analysis::Pass
  def initialize(edges:, seeds:)
    @edges = edges  # Hash[Point → Array[Point]]
    @seeds = seeds  # Array[Point]
    @lattice = Frozone::Compiler::Analysis::TwoValueLattice.new(
      bottom_value: :unreachable,
      top_value:    :reachable,
    )
  end

  def lattice = @lattice
  def seed = @seeds.each_with_object({}) { |s, h| h[s] = :reachable }

  def transfer(point, value, _lookup)
    return {} unless value == :reachable
    targets = @edges[point] || []
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
    it 'reaches all forward-transitive points and ignores unreachable subgraph' do
      values = described_class.new(pass, mode: :eager).run
      reachable = values.select { |_, v| v == :reachable }.keys.to_set
      expect(reachable).to eq(Set[:a, :b, :c, :d, :e, :f])
      expect(values[:g]).to eq(:unreachable)
      expect(values[:h]).to eq(:unreachable)
    end

    it 'terminates on cycles' do
      # The cycle a → c → e → a must be detected via the subsumes? check
      # in enqueue_update (no progress → skip re-enqueue).
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
      values = described_class.new(empty_pass).run
      expect(values.to_h).to eq({})
      # Lookups still return bottom for unseen points.
      expect(values[:a]).to eq(:unreachable)
    end
  end
end
