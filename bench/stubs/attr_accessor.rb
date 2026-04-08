$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/attr_accessor'

# Under --aot, everything below is compiled to Crystal.
last = 0
300.times { last = OBJ.get_value_loop }
puts last
