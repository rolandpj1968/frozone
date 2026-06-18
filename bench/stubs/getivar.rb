$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/getivar'

# Under --aot, everything below is compiled.
last = 0
300.times { last = OBJ.get_value_loop }
puts last
