$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x); x; end
# Suppress post-load verification
ENV["RUBY_BENCH_RACTOR_HARNESS"] = "1"
require_relative '../benchmarks/str_concat'

# Under --aot, everything below is compiled to Crystal.
# Reduced from the original 100*100=10000 iteration count: each
# concat_test loops NUM_ITERS=10240 times doing `s << str_to_add`
# which currently allocates a fresh RubyString every iteration
# (StringObject is immutable in Frozone — see CLAUDE.md note).
# At ~122ms per concat_test the original workload takes 20+ minutes
# without mutable string buffers. Tracked: project_string_encoding /
# str_concat perf belongs with the broader string-mutation work.
3.times { concat_test }
last_len = concat_test.length
puts last_len
