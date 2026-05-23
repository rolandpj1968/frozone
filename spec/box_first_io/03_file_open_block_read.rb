# File.open block form, exercises:
#   - HPP file_open override (POSIX open + IO with iv_native_fd)
#   - block invocation under ensure-close
#   - f.read inside block -> io_read Vm body -> posix_io_read rewriter
# Reads a stable external fixture, not __FILE__ (self-reads have
# trickled parser issues with mixed UTF-8 / special chars in the
# test's own source).
File.open("/tmp/hello.rb", "r") do |f|
  body = f.read
  puts "bytes:#{body.bytesize}"
  puts "first:#{body.lines.first.chomp}"
end
puts "after-block"
