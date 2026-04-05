$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/setivar'

# Under --aot, everything below is compiled to Crystal.
obj = TheClass.new
300.times { obj.set_value_loop }
