$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/fannkuchredux/benchmark'

# Under --aot, everything below is compiled to Crystal.
last = 0
10.times { last = fannkuch(N) }
puts last
