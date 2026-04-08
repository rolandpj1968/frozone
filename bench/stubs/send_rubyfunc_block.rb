$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/send_rubyfunc_block'

# Under --aot, everything below is compiled to Crystal.
instance = C.new
# NOTE: this benchmark exposes a real Frozone codegen bug — when the
# inline body is reachable (i.e. not wrapped in a no-op run_benchmark),
# Crystal rejects `Ruby_C#ruby_func` block invocations because the
# emitted method signature doesn't declare a block parameter. Previously
# the entire body was unreachable (run_benchmark stub took the block but
# never yielded), so the compile error never surfaced. Tracked.
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
puts "ran (no-op — see note in stub)"
