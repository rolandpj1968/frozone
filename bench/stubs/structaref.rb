$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/structaref_compiled'

Frozone.compile! do
  run_benchmark(850) do
    get_value_loop(TheClass.new(1, 2, 3, 1))
  end
end
