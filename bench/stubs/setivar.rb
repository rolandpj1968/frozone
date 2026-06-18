$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/setivar'

# Under --aot, everything below is compiled.
obj = TheClass.new
last = 0
300.times { last = obj.set_value_loop }
puts last
