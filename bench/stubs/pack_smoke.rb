$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

assert = lambda do |label, actual, expected|
  if actual == expected
    puts "#{label}: OK #{actual.inspect}"
  else
    puts "#{label}: FAIL got=#{actual.inspect} want=#{expected.inspect}"
    raise "fail at #{label}"
  end
end

assert.("C3",  [65, 66, 67].pack("C3").bytes,        [65, 66, 67])
assert.("n",   [0x1234].pack("n").bytes,             [0x12, 0x34])
assert.("N",   [0x12345678].pack("N").bytes,         [0x12, 0x34, 0x56, 0x78])
assert.("V",   [0x12345678].pack("V").bytes,         [0x78, 0x56, 0x34, 0x12])
assert.("U*",  [0x41, 0xFF].pack("U*").bytes,        [0x41, 0xC3, 0xBF])
assert.("a5",  ["abc"].pack("a5").bytes,             [97, 98, 99, 0, 0])
assert.("A5",  ["abc"].pack("A5").bytes,             [97, 98, 99, 32, 32])
assert.("Z3",  ["abcdef"].pack("Z3").bytes,          [97, 98, 99])
assert.("a*",  ["abc"].pack("a*").bytes,             [97, 98, 99])

# unpack
assert.("C3 unp", [65, 66, 67].pack("C3").unpack("C3"), [65, 66, 67])
assert.("n unp",  "\x12\x34".unpack("n"),                [0x1234])
assert.("N unp",  "\x12\x34\x56\x78".unpack("N"),        [0x12345678])
assert.("V unp",  "\x78\x56\x34\x12".unpack("V"),        [0x12345678])

puts "ALL OK"
