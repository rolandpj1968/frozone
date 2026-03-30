# Frozone compilation stub for matmul benchmark.
#
# Load phase: require the benchmark (matgen/matmul defined, N settles).
# Execute phase: everything after the require is compiled to Crystal via --aot.

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)

def run_benchmark(*, &); end

def make_shareable(x) = x

require_relative '../benchmarks/matmul'

# Under --aot, everything below is compiled to Crystal.
# Correctness check
a = matgen(N)
b = matgen(N)
c = matmul(a, b)
n = N
result = c[n / 2][n / 2]
expected = -18.9179166625
raise "matmul: got #{result}, expected #{expected}" unless result == expected

20.times do
  a = matgen(N)
  b = matgen(N)
  _c = matmul(a, b)
end
