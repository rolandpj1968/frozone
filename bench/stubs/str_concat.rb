$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
def make_shareable(x); x; end
require_relative '../benchmarks/str_concat'

Frozone.compile! do
  run_benchmark(100) do
    100.times { concat_test }
  end
end
