$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x); x; end
require_relative '../benchmarks/blurhash/benchmark'

# Under --aot, everything below is compiled to Crystal.
10.times { Blurhash.encode_rb(204, 204, ARRAY) }
