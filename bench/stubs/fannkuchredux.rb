$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/fannkuchredux/benchmark'

# Under --aot, everything below is compiled to Crystal.
# fannkuch returns [sum, maxflips] — destructure so each local has a
# consistent scalar type (Int64) across the loop.
sum = 0
flips = 0
10.times { sum, flips = fannkuch(N) }
puts sum
puts flips
