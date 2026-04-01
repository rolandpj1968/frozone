# Frozone compilation stub for matmul benchmark.
#
# Load phase: require the benchmark (matgen/matmul defined, N settles).
# Execute phase: everything after the require is compiled to Crystal via --aot.

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x) = x
require_relative '../benchmarks/matmul'

# Under --aot, everything below is compiled to Crystal.
20.times do
  a = matgen(N)
  b = matgen(N)
  _c = matmul(a, b)
end
