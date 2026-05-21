# Per-line iteration with gets loop. Exercises posix_io_gets +
# posix_io_eof_q rewrites. Reads this very file.
File.open(__FILE__, "r") do |f|
  n = 0
  while (line = f.gets)
    n += 1
  end
  puts "lines:#{n}"
end
