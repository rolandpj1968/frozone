$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/keyword_args'

# Under --aot, everything below is compiled.
last = 0
3.times do
  5000.times do |i|
    add(left: 1, right: 0)
    add(left: 1, right: 1)
    add(left: 1, right: 2)
    add(left: 1, right: 3)
    last = add(left: 1, right: 4)
  end
end
puts last
