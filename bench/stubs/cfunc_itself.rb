$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/cfunc_itself'

Frozone.compile! do
  run_benchmark(500) do
    500000.times do |i|
      itself
      itself
      itself
      itself
      itself
      itself
      itself
      itself
      itself
      itself
    end
  end
end
