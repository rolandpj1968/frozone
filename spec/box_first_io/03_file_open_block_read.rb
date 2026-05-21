# File.open block form — exercises:
#  - HPP file_open override (POSIX open(2) + Frozone_Vm_IOObject w/ iv_native_fd)
#  - block invocation under ensure-close
#  - f.read inside block → io_read Vm body → posix_io_read rewriter
File.open(__FILE__, "r") do |f|
  body = f.read
  puts "bytes:#{body.bytesize}"
  puts "first:#{body.lines.first.chomp}"
end
puts "after-block"
