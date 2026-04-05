$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/structaref_compiled'

# Under --aot, everything below is compiled to Crystal.
obj = TheClass.new(1, 2, 3, 1)
850.times { get_value_loop(obj) }
