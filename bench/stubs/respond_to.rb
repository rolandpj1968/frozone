$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/respond_to'

# Under --aot, everything below is compiled to Crystal.
a = A.new
b = B.new
c = C.new
run_benchmark(1000) do
  500000.times do |i|
    a.respond_to?(:foo)
    a.respond_to?(:foo2)
    a.respond_to?(:bar)
    a.respond_to?(:bar2)
    b.respond_to?(:foo)
    b.respond_to?(:foo2)
    b.respond_to?(:bar)
    b.respond_to?(:bar2)
    c.respond_to?(:foo)
    c.respond_to?(:foo2)
    c.respond_to?(:bar)
    c.respond_to?(:bar2)
  end
end
