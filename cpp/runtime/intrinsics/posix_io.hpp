// POSIX-fd-backed IO primitives for box-first.
// Used by the cpp.rb pattern rewriter — when it sees
// `RECV.native_io.X(args)` inside a Vm intrinsic body, it emits
// `posix_io_X(RECV, args)` instead. Each helper extracts the
// IOObject's @native_fd ivar (an Integer wrapping the POSIX fd)
// and operates on it directly via read(2)/write(2)/close(2)/etc.,
// bypassing the Vm @native_io facade that assumes MRI's IO.
//
// In interpreter mode the rewrite doesn't fire — Vm bodies execute
// as-is on MRI's IO.
//
// Returns: Ruby-side values that the surrounding Vm body expects to
// pass to n2f_str / n2f_int etc. For posix_io_read that's a
// Frozone String* (or nil). Each helper documents its return.

#ifndef FROZONE_POSIX_IO_HPP
#define FROZONE_POSIX_IO_HPP

namespace posix_io_detail {
  // Extract the IOObject's iv_native_fd as an int. Caller must ensure
  // `io` is a Frozone_Vm_IOObject. Returns -1 if @native_fd is nil
  // (which signals the caller they're operating on a stream without
  // POSIX backing — e.g. an IOObject from a non-box-first path).
  inline int fd_of(BasicObject* io) {
    auto* iv = static_cast<Frozone_Vm_IOObject*>(io)->iv_native_fd;
    if (!iv || iv == nil_instance()) return -1;
    return static_cast<int>(static_cast<Integer*>(iv)->raw_);
  }
}

// All stubbed for now — bodies coming in next iteration. NotImplemented
// rather than abort so callers can rescue while we iterate.
[[noreturn]] inline void posix_io_unimpl_(const char* op) {
  std::fprintf(stderr, "[box-first] posix_io_%s not yet implemented\n", op);
  std::abort();
}

// read(2) loop: keeps reading until EOF (when len is nil) or until
// the requested bytes have been collected (when len is an Integer).
// Returns a fresh Frozone String — or nil on EOF when len was given
// and zero bytes were read (mirrors MRI's IO#read semantics).
inline BasicObject* posix_io_read(BasicObject* io, BasicObject* len = nil_instance()) {
  int fd = posix_io_detail::fd_of(io);
  if (fd < 0) posix_io_unimpl_("read (no @native_fd — IOObject not box-first-fd-backed)");
  bool read_all = (len == nil_instance());
  int64_t want = read_all ? std::numeric_limits<int64_t>::max() : static_cast<Integer*>(len)->raw_;
  std::vector<std::uint8_t, GcAllocator<std::uint8_t>> buf;
  buf.reserve(read_all ? 4096 : static_cast<std::size_t>(want));
  char chunk[8192];
  while (want > 0) {
    std::size_t to_read = (want > (int64_t)sizeof(chunk)) ? sizeof(chunk) : static_cast<std::size_t>(want);
    ssize_t n = ::read(fd, chunk, to_read);
    if (n < 0) {
      if (errno == EINTR) continue;
      break;
    }
    if (n == 0) break;  // EOF
    buf.insert(buf.end(), chunk, chunk + n);
    want -= n;
  }
  if (!read_all && buf.empty()) return nil_instance();
  auto* s = new String();
  s->bytes = std::move(buf);
  return s;
}

inline BasicObject* posix_io_write(BasicObject* io, BasicObject* str) {
  int fd = posix_io_detail::fd_of(io);
  if (fd < 0) posix_io_unimpl_("write (no @native_fd)");
  auto* s = dynamic_cast<String*>(str);
  if (!s) {
    // Coerce via to_s — but caller's Vm body usually already did this.
    // Fall through to abort to keep behaviour explicit.
    posix_io_unimpl_("write (non-String arg)");
  }
  std::size_t total = 0;
  const std::uint8_t* data = s->bytes.data();
  std::size_t remaining = s->bytes.size();
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

inline BasicObject* posix_io_close(BasicObject* io) {
  int fd = posix_io_detail::fd_of(io);
  if (fd >= 0) ::close(fd);
  // Clear the fd to mark closed.
  static_cast<Frozone_Vm_IOObject*>(io)->iv_native_fd = nil_instance();
  return nil_instance();
}
inline BasicObject* posix_io_gets(BasicObject* /*io*/, BasicObject* /*sep*/) { posix_io_unimpl_("gets"); }
inline BasicObject* posix_io_gets(BasicObject* /*io*/, BasicObject* /*sep*/, BasicObject* /*limit*/) { posix_io_unimpl_("gets/3"); }
inline BasicObject* posix_io_puts(BasicObject* /*io*/, BasicObject* /*x*/) { posix_io_unimpl_("puts"); }
inline BasicObject* posix_io_eof_q(BasicObject* /*io*/) { posix_io_unimpl_("eof_q"); }
inline BasicObject* posix_io_sync(BasicObject* /*io*/) { posix_io_unimpl_("sync"); }
inline BasicObject* posix_io_sync_set(BasicObject* /*io*/, BasicObject* /*v*/) { posix_io_unimpl_("sync_set"); }
inline BasicObject* posix_io_fileno(BasicObject* io) {
  int fd = posix_io_detail::fd_of(io);
  if (fd < 0) posix_io_unimpl_("fileno (no @native_fd)");
  return new Integer(static_cast<int64_t>(fd));
}

inline BasicObject* posix_io_isatty(BasicObject* io) {
  int fd = posix_io_detail::fd_of(io);
  if (fd < 0) return false_instance();
  return boxed_bool(::isatty(fd) == 1);
}

inline BasicObject* posix_io_closed_q(BasicObject* io) {
  return boxed_bool(posix_io_detail::fd_of(io) < 0);
}

inline BasicObject* posix_io_flush(BasicObject* io) {
  // No userspace buffering in posix_io_write — every call is direct
  // write(2). Just sync the kernel buffer. Return self in MRI; we
  // return nil for simplicity (Vm body wraps anyway).
  int fd = posix_io_detail::fd_of(io);
  if (fd >= 0) ::fsync(fd);  // best-effort
  return nil_instance();
}
inline BasicObject* posix_io_seek(BasicObject* /*io*/, BasicObject* /*off*/, BasicObject* /*whence*/) { posix_io_unimpl_("seek"); }
inline BasicObject* posix_io_pos(BasicObject* /*io*/) { posix_io_unimpl_("pos"); }
inline BasicObject* posix_io_pos_set(BasicObject* /*io*/, BasicObject* /*p*/) { posix_io_unimpl_("pos_set"); }
inline BasicObject* posix_io_rewind(BasicObject* /*io*/) { posix_io_unimpl_("rewind"); }
inline BasicObject* posix_io_getbyte(BasicObject* /*io*/) { posix_io_unimpl_("getbyte"); }
inline BasicObject* posix_io_getc(BasicObject* /*io*/) { posix_io_unimpl_("getc"); }
inline BasicObject* posix_io_readbyte(BasicObject* /*io*/) { posix_io_unimpl_("readbyte"); }
inline BasicObject* posix_io_readchar(BasicObject* /*io*/) { posix_io_unimpl_("readchar"); }
inline BasicObject* posix_io_binmode(BasicObject* /*io*/) { posix_io_unimpl_("binmode"); }

#endif  // FROZONE_POSIX_IO_HPP
