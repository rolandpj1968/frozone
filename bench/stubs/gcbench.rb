$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/gcbench_compiled'

# Under --aot, everything below is compiled.
gc_make_tree(STRETCH_TREE_DEPTH)

long_lived_tree = GCNode.new
gc_populate(LONG_LIVED_TREE_DEPTH, long_lived_tree)

10.times { GCBench::MIN_TREE_DEPTH.step(GCBench::MAX_TREE_DEPTH, 2) { |depth| GCBench.time_construction(depth) } }
