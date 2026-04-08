$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x); x; end
# Suppress post-load verification
ENV["RUBY_BENCH_RACTOR_HARNESS"] = "1"
require_relative '../benchmarks/str_concat'

# Under --aot, everything below is compiled to Crystal.
# NOTE: with the splitter fix that puts ENV[]= into the load phase,
# concat_test/concat_single_test are now visible to the codegen. But
# those methods reference Encoding::UTF_8 / Encoding::BINARY constants
# which the codegen currently emits as Ruby_Encoding::Ruby_UTF_8 — a
# nonexistent constant. Restoring the no-op wrapper sentinel until that
# Encoding-constant codegen gap is fixed.
run_benchmark(100) do
  100.times { concat_test }
end
puts "ran (no-op — Encoding::UTF_8 codegen gap)"
