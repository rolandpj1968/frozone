$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
require_relative '../benchmarks/ruby-xor'

Frozone.compile! do
  run_benchmark(20) do
    a = A
    b = B
    for i in 0...20_000
      ruby_xor!(a.dup, b)
    end
  end
end
