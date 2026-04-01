$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/nqueens'

# Under --aot, everything below is compiled to Crystal.
result = nq_solve(8)
raise "nq_solve(8) = #{result}, expected 92" unless result == 92

3.times { nq_solve(8) }
