$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/fib'

Frozone.compile! do
  # Correctness check
  result = fib(35)
  raise "fib(35) = #{result}, expected 9227465" unless result == 9227465

  run_benchmark(3) do
    fib(35)
  end
end
