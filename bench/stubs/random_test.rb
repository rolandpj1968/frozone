$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# Random.new(seed).rand regression test.
# Bug: intrinsic_random_new allocated `new Random()` without invoking
# m_initialize, so universe.rb's MT19937 class state (mt_[], seed_)
# stayed zero — every `Random.new(seed).rand` returned 0.0. Splay
# benchmark hung (insert_new_node's `loop { next if tree.find(key) }`
# spun because every find matched the root 0.0).

rng = Random.new(42)
# First 5 draws — MT19937 with seed=42 produces this byte-for-byte
# under MRI; box-first must match.
puts rng.rand               # 0.3745401188473625
puts rng.rand               # 0.9507143064099162
puts rng.rand               # 0.7319939418114051
puts rng.rand               # 0.5986584841970366
puts rng.rand               # 0.15601864044243652

# Seed roundtrip.
puts Random.new(123).seed   # 123
puts Random.new(0).seed     # 0

# Distinct seeds give different sequences.
r1 = Random.new(1).rand
r2 = Random.new(2).rand
puts(r1 == r2 ? "FAIL" : "ok-distinct")

# Bounded rand(n) — must produce a non-negative Integer < n.
b = Random.new(99).rand(100)
puts(b.is_a?(Integer) && b >= 0 && b < 100 ? "ok-bounded" : "FAIL")
