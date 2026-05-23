// Io-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_IO_INTRINSICS_HPP
#define FROZONE_IO_INTRINSICS_HPP


// Raw write to stdout/stderr — direct fwrite, no dispatch chain.
// Used by box-first compiled `io_write` when the receiver IOObject's
// @native_io is nil (chicken-egg: GLOBALS["$stdout"] is set at vm.rb
// bootstrap to IOObject.new(nil, …, stream_tag: :stdout), so the
// stream identity lives on the IOObject's @stream_tag ivar). The
// Ruby io_write detects native.nil? and routes here based on the tag.
// Return value: byte count written (Integer).
inline BasicObject* intrinsic_io_raw_write_stdout(BasicObject* /*self_*/, BasicObject* s) {
  auto* str = dynamic_cast<String*>(s);
  if (!str) {
    std::fprintf(stderr, "[box-first] io_raw_write_stdout: non-String arg (got %s)\n",
                 s ? s->ruby_class_name() : "(null)");
    std::abort();
  }
  std::size_t n = std::fwrite(str->bytes.data(), 1, str->bytes.size(), stdout);
  return new Integer(static_cast<int64_t>(n));
}

inline BasicObject* intrinsic_io_raw_write_stderr(BasicObject* /*self_*/, BasicObject* s) {
  auto* str = dynamic_cast<String*>(s);
  if (!str) {
    std::fprintf(stderr, "[box-first] io_raw_write_stderr: non-String arg (got %s)\n",
                 s ? s->ruby_class_name() : "(null)");
    std::abort();
  }
  std::size_t n = std::fwrite(str->bytes.data(), 1, str->bytes.size(), stderr);
  return new Integer(static_cast<int64_t>(n));
}

// Generic POSIX write to an arbitrary fd — used by Vm io_write Vm body
// (in io_intrinsics.rb) for IOObject instances that have @native_fd
// set to a file descriptor opened via file_open (not the bootstrap
// fd 1/2 paths). Bypasses Frozone IO machinery — direct write(2).
inline BasicObject* intrinsic_io_raw_write_fd(BasicObject* /*self_*/, BasicObject* fd_obj, BasicObject* s) {
  auto* fd_i = dynamic_cast<Integer*>(fd_obj);
  auto* str = dynamic_cast<String*>(s);
  if (!fd_i || !str) {
    std::fprintf(stderr, "[box-first] io_raw_write_fd: bad args (fd=%s, s=%s)\n",
                 fd_obj ? fd_obj->ruby_class_name() : "(null)",
                 s ? s->ruby_class_name() : "(null)");
    std::abort();
  }
  int fd = static_cast<int>(fd_i->raw_);
  std::size_t total = 0;
  const std::uint8_t* data = str->bytes.data();
  std::size_t remaining = str->bytes.size();
  while (remaining > 0) {
    ssize_t n = ::write(fd, data + total, remaining);
    if (n < 0) {
      if (errno == EINTR) continue;
      break;
    }
    total += n;
    remaining -= n;
  }
  return new Integer(static_cast<int64_t>(total));
}
#endif  // FROZONE_IO_INTRINSICS_HPP
