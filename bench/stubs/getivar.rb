$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/getivar'

# Under --aot, everything below is compiled to Crystal.
3.times { OBJ.get_value_loop }
