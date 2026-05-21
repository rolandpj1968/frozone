# Round-trip: write a temp file, read it back.
# Exercises posix_io_write through the file_open 'w' mode path.
path = "/tmp/frozone_box_io_roundtrip_#{Process.pid}.txt"
File.open(path, "w") { |f| f.write("hello\nworld\n") }
contents = File.read(path)
puts "rt:#{contents.bytesize}:#{contents.chomp.gsub("\n", "|")}"
File.delete(path) rescue nil
