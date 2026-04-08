$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/ruby-xor'

# Under --aot, everything below is compiled to Crystal.
a = A
b = B
sum = 0
2000.times do
  result = ruby_xor!(a.dup, b)
  sum = sum + result.length
end
puts sum
