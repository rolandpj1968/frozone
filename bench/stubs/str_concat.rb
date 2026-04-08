$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x); x; end
# Suppress post-load verification
ENV["RUBY_BENCH_RACTOR_HARNESS"] = "1"
require_relative '../benchmarks/str_concat'

# Under --aot, everything below is compiled to Crystal.
last_len = 0
100.times do
  100.times { last_len = concat_test.length }
end
puts last_len
