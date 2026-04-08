$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/nqueens'

# Under --aot, everything below is compiled to Crystal.
last = 0
500.times { last = nq_solve(12) }
puts last
