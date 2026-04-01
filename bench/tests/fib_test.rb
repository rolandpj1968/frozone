def run_benchmark(*, &); end
require_relative '../benchmarks/fib'
result = fib(35)
raise "fib(35) = #{result}, expected 9227465" unless result == 9227465
puts "fib: OK"
