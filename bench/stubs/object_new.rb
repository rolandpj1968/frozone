$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/object_new'

Frozone.compile! do
  run_benchmark(3) do
    i = 0
    while i < 1000
      Object.new
      i += 1
    end
  end
end
