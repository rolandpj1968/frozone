$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../benchmarks/ruby-xor'

# Under --aot, everything below is compiled to Crystal.
# Correctness check
out = ruby_xor!(A.dup, B)
expected = [0,0,0,0,0,0,0,0,0,76,31,0,78,6,0,31,27,28,14,78,20,84,5,0,26,15,0,25,6,84,29,83,11,9,85,25,83,6,9,27,24,69,13,27,29,84,28,15,16,18,0,0,0,0,0,0,0,0,0,0,0,29,0,5,0]
actual = []
i = 0
while i < out.bytesize
  actual << out.getbyte(i)
  i += 1
end
raise "ruby_xor! wrong output" unless actual == expected

a = A
b = B
20.times { ruby_xor!(a.dup, b) }
