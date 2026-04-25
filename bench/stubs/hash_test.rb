$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# Symbol-keyed hash
h = { foo: 10, bar: 20, baz: 30 }
puts h[:foo]
puts h[:bar]
puts h[:baz]
puts h.size

# Integer-keyed hash (value-based key equality via m_hash_value/m_eq_q)
g = { 1 => 100, 2 => 200, 3 => 300 }
puts g[1]
puts g[2]
puts g[3]
puts g.size

# Mutation
h[:qux] = 99
puts h[:qux]
puts h.size

# Missing key returns nil-instance — test via has_key?
puts h.has_key?(:foo)
puts h.has_key?(:nonexistent)
