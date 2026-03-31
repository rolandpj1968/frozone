$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(n, &); n.times { yield }; end
def make_shareable(x); x; end
# Suppress post-load verification
ENV["RUBY_BENCH_RACTOR_HARNESS"] = "1"
require_relative '../benchmarks/str_concat'

# Under --aot, everything below is compiled to Crystal.
run_benchmark(100) do
  100.times { concat_test }
end
