# Frozone compilation stub for matmul benchmark.
#
# Load phase: require the benchmark (matgen/matmul defined, N settles).
# Execute phase: everything after the require is compiled via --aot.

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x) = x
require_relative '../benchmarks/matmul'

# Under --aot, everything below is compiled.
last = 0.0
20.times do
  a = matgen(N)
  b = matgen(N)
  c = matmul(a, b)
  last = c[N / 2][N / 2]
end
puts last
