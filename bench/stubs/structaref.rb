$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/structaref_compiled'

# Under --aot, everything below is compiled.
obj = TheClass.new(1, 2, 3, 1)
last = 0
850.times { last = get_value_loop(obj) }
puts last
