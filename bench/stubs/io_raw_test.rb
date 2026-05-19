$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# Direct invocation of the new HPP intrinsics — bypasses the IOObject /
# native_io chain. Returns the byte count.
n1 = Intrinsics.io_raw_write_stdout(self, "hello-from-stdout\n")
n2 = Intrinsics.io_raw_write_stderr(self, "hello-from-stderr\n")
puts "stdout-bytes=#{n1}"
puts "stderr-bytes=#{n2}"
