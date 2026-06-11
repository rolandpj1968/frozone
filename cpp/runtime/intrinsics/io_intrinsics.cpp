// Io-category intrinsic definitions. Declarations live in
// io_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "io_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

// Raw write to stdout/stderr — direct fwrite, no dispatch chain.
// Used by box-first compiled `io_write` when the receiver IOObject's
// @native_io is nil (chicken-egg: GLOBALS["$stdout"] is set at vm.rb
// bootstrap to IOObject.new(nil, …, stream_tag: :stdout), so the
// stream identity lives on the IOObject's @stream_tag ivar). The
// Ruby io_write detects native.nil? and routes here based on the tag.
// Return value: byte count written (Integer).
BasicObject* intrinsic_io_raw_write_stdout(BasicObject* /*self_*/, BasicObject* s) {
  if (!s || typeid(*s) != typeid(String)) {
    std::fprintf(stderr, "[box-first] io_raw_write_stdout: non-String arg (got %s)\n",
                 s ? s->ruby_class_name() : "(null)");
    std::abort();
  }
  auto* str = static_cast<String*>(s);
  std::size_t n = std::fwrite(str->bytes.data(), 1, str->bytes.size(), stdout);
  return new Integer(static_cast<int64_t>(n));
}

BasicObject* intrinsic_io_raw_write_stderr(BasicObject* /*self_*/, BasicObject* s) {
  if (!s || typeid(*s) != typeid(String)) {
    std::fprintf(stderr, "[box-first] io_raw_write_stderr: non-String arg (got %s)\n",
                 s ? s->ruby_class_name() : "(null)");
    std::abort();
  }
  auto* str = static_cast<String*>(s);
  std::size_t n = std::fwrite(str->bytes.data(), 1, str->bytes.size(), stderr);
  return new Integer(static_cast<int64_t>(n));
}


}  // namespace Ruby
