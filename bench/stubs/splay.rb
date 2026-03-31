$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(n, &); n.times { yield }; end
require_relative '../benchmarks/splay'

# Under --aot, everything below is compiled to Crystal.
rng = Random.new(42)
tree = splay_setup(rng)
run_benchmark(200) do
  50.times { splay_run(tree, rng) }
end
