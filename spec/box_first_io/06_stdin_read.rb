# $stdin.read via shell-redirect. Exercises posix_io_read on fd 0
# (set in vm.rb bootstrap as native_fd=0).
data = $stdin.read
puts "got:#{data.bytesize}:#{data.chomp.gsub("\n", "|")}"
