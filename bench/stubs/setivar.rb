$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/setivar'

Frozone.compile! do
  obj = TheClass.new
  run_benchmark(3) do
    obj.set_value_loop
  end
end
