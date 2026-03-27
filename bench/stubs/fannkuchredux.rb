$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/fannkuchredux/benchmark'

Frozone.compile! do
  run_benchmark(10) do
    sum, flips = fannkuch(N)
  end
end
