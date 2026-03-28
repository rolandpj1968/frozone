$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*); end
def make_shareable(x); x; end
require_relative '../benchmarks/blurhash/benchmark'

Frozone.compile! do
  # Correctness check
  result = Blurhash.encode_rb(204, 204, ARRAY)
  expected = "LFE.@D9F01_2%L%MIVD*9Goe-;WB"
  raise "blurhash wrong: got #{result}, expected #{expected}" unless result == expected

  run_benchmark(10) do
    Blurhash.encode_rb(204, 204, ARRAY)
  end
end
