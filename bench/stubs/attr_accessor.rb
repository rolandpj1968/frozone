$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/attr_accessor'

# Under --aot, everything below is compiled to Crystal.
obj = TheClass.new
run_benchmark(3) do
  obj.get_value_loop
end
