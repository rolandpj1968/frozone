$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# Default String → UTF-8
s = String.new
puts "init enc: #{s.encoding.name}"
raise "expected UTF-8 init" unless s.encoding.equal?(Encoding::UTF_8)

# force_encoding flips
s.force_encoding(Encoding::BINARY)
puts "after force_encoding: #{s.encoding.name}"
raise "expected BINARY after force" unless s.encoding.equal?(Encoding::BINARY)

# Append byte 255 in BINARY → single byte 0xFF
s << 255
puts "bytesize after << 255: #{s.bytesize}"
puts "bytes: #{s.bytes.inspect}"
raise "expected single 0xFF" unless s.bytes == [255]

# Integer#chr defaults to UTF-8 → 0xFF needs 2 bytes (C3 BF)
chr_utf8 = 255.chr
puts "255.chr (UTF-8) bytes: #{chr_utf8.bytes.inspect}"
puts "255.chr (UTF-8) encoding: #{chr_utf8.encoding.name}"
raise "expected UTF-8 0xC3 0xBF" unless chr_utf8.bytes == [0xC3, 0xBF]

# Integer#chr(BINARY) → single byte 0xFF
chr_bin = 255.chr(Encoding::BINARY)
puts "255.chr(BINARY) bytes: #{chr_bin.bytes.inspect}"
puts "255.chr(BINARY) encoding: #{chr_bin.encoding.name}"
raise "expected BINARY single 0xFF" unless chr_bin.bytes == [255]

puts "OK"
