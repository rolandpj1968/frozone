$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x); x; end
require_relative '../benchmarks/blurhash/benchmark'

# Under --aot, everything below is compiled to Crystal.
last = ""
10.times { last = Blurhash.encode_rb(204, 204, ARRAY) }
puts last
