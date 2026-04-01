$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/ruby-xor'

# Under --aot, everything below is compiled to Crystal.
a = A
b = B
20.times { ruby_xor!(a.dup, b) }
