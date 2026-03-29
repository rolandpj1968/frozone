# Like nqueens_stub but dumps TypeInference results instead of emitting Crystal.
$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/nqueens'

# Under --aot, everything below is compiled to Crystal.
run_benchmark(3) do
  nq_solve(8)
end
