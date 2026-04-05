$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/structaset_compiled'

# Under --aot, everything below is compiled to Crystal.
obj = TheSetClass.new(1, 2, 3, 1)
850.times { obj.set_value_loop }
