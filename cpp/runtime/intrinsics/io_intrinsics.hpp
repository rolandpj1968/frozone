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
#endif  // FROZONE_IO_INTRINSICS_HPP
