$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/loops-times'

Frozone.compile! do
  run_benchmark(10) do
    a = Array.new(10000, 0)

    4_000.times do |i|
      4_000.times do |j|
        a[i] += j % U
      end
      a[i] += R
    end
  end
end
