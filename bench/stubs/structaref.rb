$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/structaref_compiled'

# Under --aot, everything below is compiled to Crystal.
run_benchmark(850) do
  get_value_loop(TheClass.new(1, 2, 3, 1))
end
