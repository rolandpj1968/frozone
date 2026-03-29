$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/gcbench_compiled'

# Under --aot, everything below is compiled to Crystal.
gc_make_tree(STRETCH_TREE_DEPTH)

long_lived_tree = GCNode.new
gc_populate(LONG_LIVED_TREE_DEPTH, long_lived_tree)

run_benchmark(10) do
  depth = MIN_TREE_DEPTH
  while depth <= MAX_TREE_DEPTH
    gc_time_construction(depth)
    depth += 2
  end
end
