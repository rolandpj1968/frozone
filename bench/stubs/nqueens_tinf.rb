# Like nqueens_stub but dumps TypeInference results instead of emitting Crystal.
$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/nqueens'

# Under --aot, everything below is compiled to Crystal.
last = 0
3.times do
  last = nq_solve(8)
end
puts last
