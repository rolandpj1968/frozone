$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/nqueens'

Frozone.compile! do
  result = nq_solve(8)
  raise "nq_solve(8) = #{result}, expected 92" unless result == 92

  run_benchmark(3) do
    nq_solve(8)
  end
end
