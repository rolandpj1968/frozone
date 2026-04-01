def run_benchmark(*, &); end
require_relative '../benchmarks/nqueens'
result = nq_solve(8)
raise "nq_solve(8) = #{result}, expected 92" unless result == 92
puts "nqueens: OK"
