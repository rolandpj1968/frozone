$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x) = x
require_relative '../benchmarks/matmul'
a = matgen(N)
b = matgen(N)
c = matmul(a, b)
n = N
result = c[n / 2][n / 2]
expected = -18.9179166625
raise "matmul: got #{result}, expected #{expected}" unless result == expected
puts "matmul: OK"
