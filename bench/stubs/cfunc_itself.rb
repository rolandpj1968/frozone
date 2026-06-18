$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/cfunc_itself'

# Under --aot, everything below is compiled.
count = 0
500.times do
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
    count = count + 1
  end
end
puts count
