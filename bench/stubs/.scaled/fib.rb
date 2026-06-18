$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../benchmarks/fib'

# Under --aot, everything below is compiled.
total = 0
1.times { total = total + fib(35) }
puts total
