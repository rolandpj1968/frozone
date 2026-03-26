$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/fib'

Frozone.compile! do
  run_benchmark(3) do
    fib(20)
  end
end
