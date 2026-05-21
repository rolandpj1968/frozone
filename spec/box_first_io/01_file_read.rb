# Simplest: File.read of a known-fixed file via intrinsic_file_read.
# Was working pre-rewriter (HPP_INTRINSICS file_read), regression test.
content = File.read(__FILE__)
puts "bytes:#{content.bytesize}"
puts "first:#{content.lines.first.chomp}"
