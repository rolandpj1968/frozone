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
  // `io` is a IO. Returns -1 if @native_fd is nil
  // (which signals the caller they're operating on a stream without
  // POSIX backing — e.g. an IOObject from a non-box-first path).
  inline int fd_of(BasicObject* io) {
    auto* iv = static_cast<IO*>(io)->iv_native_fd;
    if (!iv || iv == nil_instance()) return -1;
    return static_cast<int>(static_cast<Integer*>(iv)->raw_);
  }

  // Parse an MRI-style mode string into POSIX open(2) flags.
  // Handles the common letters: r/w/a (+ optional '+' for read-write,
  // 'b' / 't' ignored, ':' / encoding suffix ignored). Returns
  // O_RDONLY for unknown / empty modes (mirrors MRI default).
  inline int parse_mode(const char* mode_str, std::size_t n) {
    if (!mode_str || n == 0) return O_RDONLY;
    char first = mode_str[0];
    bool plus = false;
    for (std::size_t i = 1; i < n && mode_str[i] != ':'; i++) {
      if (mode_str[i] == '+') { plus = true; break; }
    }
    switch (first) {
      case 'r': return plus ? O_RDWR : O_RDONLY;
      case 'w': return (plus ? O_RDWR : O_WRONLY) | O_CREAT | O_TRUNC;
      case 'a': return (plus ? O_RDWR : O_WRONLY) | O_CREAT | O_APPEND;
      default:  return O_RDONLY;
    }
  }
}

// File.new_from_fd(path_or_fd, mode, opts) — box-first HPP override
// of the Vm intrinsic. When path_or_fd is an Integer it's a real fd
// (e.g. from File.for_fd, $stdout backing-fd refresh); when it's a
// String we treat it as a path and open(2). Wraps the result in a
// IO with iv_native_fd set.
inline BasicObject* intrinsic_file_new_from_fd(BasicObject* path_or_fd,
                                               BasicObject* mode, BasicObject* opts) {
  int fd;
  if (path_or_fd == nil_instance() || !path_or_fd) {
    // vm.rb bootstrap path: IOObject.new($stdout, …) where $stdout
    // is nil in box-first compiled mode (no MRI IO exists). Construct
    // an empty IOObject; the bootstrap follows up with .native_fd = N
    // to set the fd explicitly. Preserve stream_tag from opts hash if
    // present (vm.rb passes stream_tag: :stdout/:stderr/:stdin).
    auto* io = new IO();
    io->iv_native_fd = nil_instance();
    io->iv_native_io = nil_instance();
    io->iv_class_object = static_cast<BasicObject*>(&IO_CLASS);
    if (auto* opts_h = dynamic_cast<Hash*>(opts)) {
      auto it = opts_h->data.find(intern("stream_tag"));
      if (it != opts_h->data.end()) {
        io->iv_stream_tag = it->second;
      }
    }
    return io;
  }
  if (auto* i = dynamic_cast<Integer*>(path_or_fd)) {
    fd = static_cast<int>(i->raw_);
  } else if (auto* s = dynamic_cast<String*>(path_or_fd)) {
    int posix_flags = O_RDONLY;
    if (auto* m = dynamic_cast<String*>(mode)) {
      posix_flags = posix_io_detail::parse_mode(
          reinterpret_cast<const char*>(m->bytes.data()), m->bytes.size());
    }
    std::string path_str(reinterpret_cast<const char*>(s->bytes.data()), s->bytes.size());
    fd = ::open(path_str.c_str(), posix_flags, 0666);
    if (fd < 0) {
      // TODO: throw Errno::ENOENT/etc — would need Frozone_Vm_FrozoneException
      // in POST_HPP_VALUE_TYPES or its own KernelFn helper. Abort for now.
      std::fprintf(stderr, "[box-first] file_new_from_fd: open(\"%s\") failed: %s\n",
                   path_str.c_str(), std::strerror(errno));
      std::abort();
    }
  } else {
    std::fprintf(stderr, "[box-first] file_new_from_fd: unsupported arg type\n");
    std::abort();
  }
  auto* io = new IO();
  io->iv_native_fd = new Integer(static_cast<int64_t>(fd));
  io->iv_native_io = nil_instance();
  io->iv_class_object = static_cast<BasicObject*>(&IO_CLASS);
  return io;
}

// IO.new(fd, mode, opts) — box-first HPP override. Vm's io_new_from_fd
// is MRI-backed (::IO.for_fd / ::IO.new); in box-first we just take a
// raw fd Integer and wrap. Currently the Vm path expects an actual fd
// (not a path); we error on String path here since IO.new(path) is
// non-canonical Ruby anyway.
inline BasicObject* intrinsic_io_new_from_fd(BasicObject* fd_obj, BasicObject* mode,
                                             BasicObject* opts) {
  return intrinsic_file_new_from_fd(fd_obj, mode, opts);
}

// File.open(path, mode, block, perm, flags, opts) — box-first HPP
// override of the Vm intrinsic. Bypasses the Vm-side `File.open(*args)`
// which calls MRI (not available in compiled mode). open(2) the path,
// build a IO with iv_native_fd, run the block under
// an ensure-close guard if given.
inline BasicObject* intrinsic_file_open(BasicObject* path, BasicObject* mode,
                                        BasicObject* block, BasicObject* perm,
                                        BasicObject* /*flags*/,
                                        BasicObject* /*extra_opts*/ = nil_instance()) {
  auto* path_s = dynamic_cast<String*>(path);
  if (!path_s) {
    std::fprintf(stderr, "[box-first] file_open: non-String path\n");
    std::abort();
  }
  std::string path_str(reinterpret_cast<const char*>(path_s->bytes.data()), path_s->bytes.size());

  int posix_flags = O_RDONLY;
  if (auto* mode_s = dynamic_cast<String*>(mode)) {
    posix_flags = posix_io_detail::parse_mode(
        reinterpret_cast<const char*>(mode_s->bytes.data()), mode_s->bytes.size());
  } else if (auto* mode_i = dynamic_cast<Integer*>(mode)) {
    posix_flags = static_cast<int>(mode_i->raw_);
  }

  mode_t perm_mode = 0666;
  if (auto* perm_i = dynamic_cast<Integer*>(perm)) {
    perm_mode = static_cast<mode_t>(perm_i->raw_);
  }

  int fd = ::open(path_str.c_str(), posix_flags, perm_mode);
  if (fd < 0) {
    // TODO: throw Errno::ENOENT/etc — needs Frozone_Vm_FrozoneException
    // in POST_HPP_VALUE_TYPES or a KernelFn helper. Abort for now.
    std::fprintf(stderr, "[box-first] file_open: open(\"%s\") failed: %s\n",
                 path_str.c_str(), std::strerror(errno));
    std::abort();
  }

  auto* io = new IO();
  io->iv_native_fd = new Integer(static_cast<int64_t>(fd));
  io->iv_native_io = nil_instance();
  io->iv_class_object = static_cast<BasicObject*>(&IO_CLASS);

  if (block != nil_instance() && block) {
    BasicObject* result = nil_instance();
    try {
      result = static_cast<Proc*>(block)->m_call(new Array({static_cast<BasicObject*>(io)}));
    } catch (...) {
      if (posix_io_detail::fd_of(io) >= 0) {
        ::close(fd);
        io->iv_native_fd = nil_instance();
      }
      throw;
    }
    if (posix_io_detail::fd_of(io) >= 0) {
      ::close(fd);
      io->iv_native_fd = nil_instance();
    }
    return result;
  }
  return io;
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
  static_cast<IO*>(io)->iv_native_fd = nil_instance();
  return nil_instance();
}
// IO#gets — read up to (and including) separator. sep nil means
// "read to EOF as one chunk". limit nil means "no byte cap". Returns
// nil at EOF when nothing was read. Byte-by-byte read(2) — slow but
// correct; can swap to a per-IO buffer later. No userspace buffer
// means $stdin / piped input is safe (no over-read).
inline BasicObject* posix_io_gets(BasicObject* io, BasicObject* sep, BasicObject* limit = nil_instance()) {
  int fd = posix_io_detail::fd_of(io);
  if (fd < 0) posix_io_unimpl_("gets (no @native_fd)");

  // Resolve separator: nil → read-to-EOF, default \n otherwise.
  std::string sep_str = "\n";
  bool sep_is_nil = (sep == nil_instance());
  if (!sep_is_nil) {
    if (auto* s = dynamic_cast<String*>(sep)) {
      sep_str.assign(reinterpret_cast<const char*>(s->bytes.data()), s->bytes.size());
    }
  }
  int64_t lim = -1;
  if (limit != nil_instance()) {
    if (auto* i = dynamic_cast<Integer*>(limit)) lim = i->raw_;
  }

  std::vector<std::uint8_t, GcAllocator<std::uint8_t>> buf;
  char c;
  while (true) {
    if (lim >= 0 && (int64_t)buf.size() >= lim) break;
    ssize_t n = ::read(fd, &c, 1);
    if (n < 0) {
      if (errno == EINTR) continue;
      break;
    }
    if (n == 0) break;
    buf.push_back(static_cast<std::uint8_t>(c));
    if (!sep_is_nil && !sep_str.empty() && buf.size() >= sep_str.size() &&
        std::memcmp(buf.data() + buf.size() - sep_str.size(), sep_str.data(), sep_str.size()) == 0) {
      break;
    }
  }
  if (buf.empty()) return nil_instance();
  auto* s = new String();
  s->bytes = std::move(buf);
  return s;
}
inline BasicObject* posix_io_puts(BasicObject* /*io*/, BasicObject* /*x*/) { posix_io_unimpl_("puts"); }
// EOF detection for regular files: stat the fd + compare position.
// For pipes/sockets/ttys (where lseek isn't meaningful), best-effort
// returns false — caller's read loop catches the actual EOF.
inline BasicObject* posix_io_eof_q(BasicObject* io) {
  int fd = posix_io_detail::fd_of(io);
  if (fd < 0) return true_instance();
  struct stat st;
  if (::fstat(fd, &st) != 0 || !S_ISREG(st.st_mode)) return false_instance();
  off_t pos = ::lseek(fd, 0, SEEK_CUR);
  if (pos < 0) return false_instance();
  return boxed_bool(pos >= st.st_size);
}
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
