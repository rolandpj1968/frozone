$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x); x; end
# Suppress post-load verification
ENV["RUBY_BENCH_RACTOR_HARNESS"] = "1"
require_relative '../benchmarks/str_concat'

# Under --aot, everything below is compiled to Crystal.
# NOTE: with the splitter ENV[]= fix (commit 0e73b81), concat_test
# and concat_single_test now reach the codegen. Remaining gap:
# `Encoding::UTF_8` and `Encoding::BINARY` constants. These currently
# emit as `Ruby_Encoding::Ruby_UTF_8` (a nonexistent class constant)
# because the Encoding module is in SKIP_CONSTANTS but its constants
# are still referenced by user code. Bridging Ruby Encoding objects to
# the Crystal RubyEncoding enum (which is a fast tag, not a RubyObject
# subtype) needs runtime singleton wrappers. Tracked separately —
# probably best tackled alongside the broader string-encoding
# specialization work in project_string_encoding_specialization.
run_benchmark(100) do
  100.times { concat_test }
end
puts "ran (no-op — Encoding::UTF_8 needs runtime bridge)"
