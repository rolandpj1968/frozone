$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/fib'

# Under --aot, everything below is compiled to Crystal.
total = 0
3.times { total = total + fib(35) }
puts total
