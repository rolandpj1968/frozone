$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/send_rubyfunc_block'

# Under --aot, everything below is compiled to Crystal.
instance = C.new
run_benchmark(500) do
  500_000.times do |i|
    instance.ruby_func {}
    instance.ruby_func {}
    instance.ruby_func {}
    instance.ruby_func {}
    instance.ruby_func {}
    instance.ruby_func {}
    instance.ruby_func {}
    instance.ruby_func {}
    instance.ruby_func {}
  end
end
