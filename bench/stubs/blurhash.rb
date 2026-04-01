$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def make_shareable(x); x; end
require_relative '../benchmarks/blurhash/benchmark'

# Under --aot, everything below is compiled to Crystal.
# Correctness check
result = Blurhash.encode_rb(204, 204, ARRAY)
expected = "LFE.@D9F01_2%L%MIVD*9Goe-;WB"
raise "blurhash wrong: got #{result}, expected #{expected}" unless result == expected

10.times { Blurhash.encode_rb(204, 204, ARRAY) }
