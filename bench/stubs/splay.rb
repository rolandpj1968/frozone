$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/splay'

Frozone.compile! do
  rng = Random.new(42)
  tree = splay_setup(rng)
  run_benchmark(200) do
    50.times { splay_run(tree, rng) }
  end
end
