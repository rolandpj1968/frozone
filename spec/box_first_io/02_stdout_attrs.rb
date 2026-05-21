# Rewriter smoke: $stdout.fileno + isatty.
# Vm bodies io_fileno / io_isatty delegate via receiver.native_io.X;
# compiler rewrites to posix_io_fileno / posix_io_isatty(receiver).
puts "fileno:#{$stdout.fileno}"
puts "isatty:#{$stdout.isatty}"
