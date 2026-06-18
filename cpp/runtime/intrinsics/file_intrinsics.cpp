// File-category intrinsic definitions. Declarations live in
// file_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "file_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

namespace fs_detail {
  inline BasicObject* stat_array(const struct stat& st) {
    return new Array({
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_mode))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_size))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_uid))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_gid))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_dev))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_ino))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_nlink))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_rdev))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_blocks))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_blksize))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_atim.tv_sec))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_atim.tv_nsec))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_mtim.tv_sec))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_mtim.tv_nsec))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_ctim.tv_sec))),
      static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_ctim.tv_nsec))),
    });
  }
}

// stat(2) — returns nil on failure, else a 16-element Array. Field
// order matches OS_STAT_* indices in lib/core/4.0/file.rb.
BasicObject* intrinsic_os_stat(BasicObject* path) {
  struct stat st;
  return ::stat(fs_detail::str_of(path).c_str(), &st) == 0 ? fs_detail::stat_array(st) : nil_instance();
}

// lstat(2) — same shape as os_stat but does not follow symlinks.
BasicObject* intrinsic_os_lstat(BasicObject* path) {
  struct stat st;
  return ::lstat(fs_detail::str_of(path).c_str(), &st) == 0 ? fs_detail::stat_array(st) : nil_instance();
}

// access(2) — mode_bits is R_OK|W_OK|X_OK (any combination of 4/2/1).
BasicObject* intrinsic_os_access(BasicObject* path, BasicObject* mode_bits) {
  int m = static_cast<int>(static_cast<Integer*>(mode_bits)->raw_);
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), m) == 0);
}

// realpath(3) — returns canonicalised absolute path, or nil on failure
// (e.g. ENOENT). Ruby side translates nil into ENOENT.
BasicObject* intrinsic_os_realpath(BasicObject* path) {
  char buf[4096];
  char* r = ::realpath(fs_detail::str_of(path).c_str(), buf);
  return r ? new String(r, std::strlen(r)) : nil_instance();
}

// readlink(2) — nil on failure. Buffer sized for PATH_MAX.
BasicObject* intrinsic_os_readlink(BasicObject* path) {
  char buf[4096];
  ssize_t n = ::readlink(fs_detail::str_of(path).c_str(), buf, sizeof(buf));
  if (n < 0) return nil_instance();
  return new String(buf, static_cast<std::size_t>(n));
}

// euid/egid for owned?/grpowned? — separate from the eu*id intrinsics in
// process_intrinsics so File doesn't pull in Process namespace.
BasicObject* intrinsic_os_euid() {
  return new Integer(static_cast<int64_t>(::geteuid()));
}

BasicObject* intrinsic_os_egid() {
  return new Integer(static_cast<int64_t>(::getegid()));
}

// ---- Mutating POSIX primitives -----------------------------------
// Each returns nil on errno failure; Ruby maps nil → the appropriate
// Errno::* via inspecting errno or trying again.

BasicObject* intrinsic_os_unlink(BasicObject* path) {
  return ::unlink(fs_detail::str_of(path).c_str()) == 0 ? true_instance() : nil_instance();
}

BasicObject* intrinsic_os_rename(BasicObject* from, BasicObject* to) {
  return ::rename(fs_detail::str_of(from).c_str(),
                  fs_detail::str_of(to).c_str()) == 0 ? true_instance() : nil_instance();
}

BasicObject* intrinsic_os_link(BasicObject* target, BasicObject* link) {
  return ::link(fs_detail::str_of(target).c_str(),
                fs_detail::str_of(link).c_str()) == 0 ? true_instance() : nil_instance();
}

BasicObject* intrinsic_os_symlink(BasicObject* target, BasicObject* link) {
  return ::symlink(fs_detail::str_of(target).c_str(),
                   fs_detail::str_of(link).c_str()) == 0 ? true_instance() : nil_instance();
}

BasicObject* intrinsic_os_chmod(BasicObject* path, BasicObject* mode) {
  mode_t m = static_cast<mode_t>(static_cast<Integer*>(mode)->raw_);
  return ::chmod(fs_detail::str_of(path).c_str(), m) == 0 ? true_instance() : nil_instance();
}

BasicObject* intrinsic_os_truncate(BasicObject* path, BasicObject* length) {
  off_t len = static_cast<off_t>(static_cast<Integer*>(length)->raw_);
  return ::truncate(fs_detail::str_of(path).c_str(), len) == 0 ? true_instance() : nil_instance();
}

// utimensat with AT_FDCWD; accepts nanosecond-precision atime/mtime.
// flags 0 follows symlinks; AT_SYMLINK_NOFOLLOW for lutime.
BasicObject* intrinsic_os_utimes(BasicObject* path,
                                        BasicObject* atime_sec, BasicObject* atime_nsec,
                                        BasicObject* mtime_sec, BasicObject* mtime_nsec,
                                        BasicObject* follow_symlinks) {
  struct timespec ts[2];
  ts[0].tv_sec = static_cast<time_t>(static_cast<Integer*>(atime_sec)->raw_);
  ts[0].tv_nsec = static_cast<long>(static_cast<Integer*>(atime_nsec)->raw_);
  ts[1].tv_sec = static_cast<time_t>(static_cast<Integer*>(mtime_sec)->raw_);
  ts[1].tv_nsec = static_cast<long>(static_cast<Integer*>(mtime_nsec)->raw_);
  int flags = (follow_symlinks == true_instance()) ? 0 : AT_SYMLINK_NOFOLLOW;
  return ::utimensat(AT_FDCWD, fs_detail::str_of(path).c_str(), ts, flags) == 0
    ? true_instance() : nil_instance();
}

BasicObject* intrinsic_os_mkfifo(BasicObject* path, BasicObject* mode) {
  mode_t m = static_cast<mode_t>(static_cast<Integer*>(mode)->raw_);
  return ::mkfifo(fs_detail::str_of(path).c_str(), m) == 0 ? true_instance() : nil_instance();
}

// umask sets+returns prior mask. nil arg → query (no change). Tricky
// because umask has no "query without change" form; emulate via
// set→reset.
BasicObject* intrinsic_os_umask(BasicObject* new_mask) {
  if (new_mask == nil_instance()) {
    mode_t prev = ::umask(0);
    ::umask(prev);
    return new Integer(static_cast<int64_t>(prev));
  }
  mode_t m = static_cast<mode_t>(static_cast<Integer*>(new_mask)->raw_);
  return new Integer(static_cast<int64_t>(::umask(m)));
}

BasicObject* intrinsic_os_fnmatch(BasicObject* pattern, BasicObject* path, BasicObject* flags) {
  int f = static_cast<int>(static_cast<Integer*>(flags)->raw_);
  return boxed_bool(
    ::fnmatch(fs_detail::str_of(pattern).c_str(),
              fs_detail::str_of(path).c_str(), f) == 0);
}

// ---- fd-level POSIX primitives -----------------------------------

BasicObject* intrinsic_os_open(BasicObject* path, BasicObject* flags, BasicObject* mode) {
  int f = static_cast<int>(static_cast<Integer*>(flags)->raw_);
  mode_t m = static_cast<mode_t>(static_cast<Integer*>(mode)->raw_);
  int fd = ::open(fs_detail::str_of(path).c_str(), f, m);
  return fd >= 0 ? static_cast<BasicObject*>(new Integer(static_cast<int64_t>(fd))) : nil_instance();
}

BasicObject* intrinsic_os_close(BasicObject* fd) {
  int f = static_cast<int>(static_cast<Integer*>(fd)->raw_);
  return ::close(f) == 0 ? true_instance() : nil_instance();
}

BasicObject* intrinsic_os_read(BasicObject* fd, BasicObject* len) {
  int f = static_cast<int>(static_cast<Integer*>(fd)->raw_);
  std::size_t n = static_cast<std::size_t>(static_cast<Integer*>(len)->raw_);
  std::vector<char> buf(n);
  ssize_t r = ::read(f, buf.data(), n);
  if (r < 0) return nil_instance();
  return new String(buf.data(), static_cast<std::size_t>(r), String::BINARY);
}

BasicObject* intrinsic_os_write(BasicObject* fd, BasicObject* bytes) {
  int f = static_cast<int>(static_cast<Integer*>(fd)->raw_);
  const auto* s = static_cast<String*>(bytes);
  ssize_t w = ::write(f, reinterpret_cast<const char*>(s->bytes.data()), s->bytes.size());
  return w >= 0 ? static_cast<BasicObject*>(new Integer(static_cast<int64_t>(w))) : nil_instance();
}

BasicObject* intrinsic_os_lseek(BasicObject* fd, BasicObject* offset, BasicObject* whence) {
  int f = static_cast<int>(static_cast<Integer*>(fd)->raw_);
  off_t o = static_cast<off_t>(static_cast<Integer*>(offset)->raw_);
  int w = static_cast<int>(static_cast<Integer*>(whence)->raw_);
  off_t r = ::lseek(f, o, w);
  return r >= 0 ? static_cast<BasicObject*>(new Integer(static_cast<int64_t>(r))) : nil_instance();
}

BasicObject* intrinsic_os_fstat(BasicObject* fd) {
  int f = static_cast<int>(static_cast<Integer*>(fd)->raw_);
  struct stat st;
  return ::fstat(f, &st) == 0 ? fs_detail::stat_array(st) : nil_instance();
}

BasicObject* intrinsic_os_isatty(BasicObject* fd) {
  int f = static_cast<int>(static_cast<Integer*>(fd)->raw_);
  return boxed_bool(::isatty(f) == 1);
}


}  // namespace Ruby
