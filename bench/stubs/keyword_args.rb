$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(n, &); n.times { yield }; end
require_relative '../benchmarks/keyword_args'

# Under --aot, everything below is compiled to Crystal.
run_benchmark(3) do
  5000.times do |i|
    add(left: 1, right: 0)
    add(left: 1, right: 1)
    add(left: 1, right: 2)
    add(left: 1, right: 3)
    add(left: 1, right: 4)
  end
end
