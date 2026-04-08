$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/object_new'

# Under --aot, everything below is compiled to Crystal.
last = nil
300.times { i = 0; while i < 1000; last = Object.new; i += 1; end }
puts last.class
