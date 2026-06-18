$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/splay'

# Under --aot, everything below is compiled.
rng = Random.new(42)
tree = splay_setup(rng)
200.times do
  50.times { splay_run(tree, rng) }
end
m = tree.find_max
puts m.key
