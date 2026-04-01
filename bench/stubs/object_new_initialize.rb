$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/object_new_initialize'

# Under --aot, everything below is compiled to Crystal.
3.times { i = 0; while i < 1000; test; i += 1; end }
