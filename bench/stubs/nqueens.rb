$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/nqueens'

# Under --aot, everything below is compiled.
last = 0
4.times { last = nq_solve(12) }
puts last
