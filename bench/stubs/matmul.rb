# Frozone compilation stub for matmul benchmark.
#
# Strategy:
#   - Pre-populate $LOADED_FEATURES with the harness loader path so that
#     matmul.rb's `require_relative '../harness/loader'` is a no-op.
#   - Define our own no-op run_benchmark/make_shareable for the load phase.
#   - Require the benchmark: matgen/matmul are defined and N settles.
#   - Frozone.compile! triggers snapshot codegen; the block is the execute phase.

$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)

def run_benchmark(*)
  # no-op during load phase — block never called
end

def make_shareable(x) = x

require_relative '../benchmarks/matmul'

Frozone.compile! do
  run_benchmark(20) do
    a = matgen(N)
    b = matgen(N)
    _c = matmul(a, b)
  end
end
