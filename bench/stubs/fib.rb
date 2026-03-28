$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/fib'

Frozone.compile! do
  # Correctness check
  result = fib(20)
  raise "fib(20) = #{result}, expected 6765" unless result == 6765

  run_benchmark(3) do
    fib(20)
  end
end
