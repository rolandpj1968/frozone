// File-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.
//
// Scope: minimal OS primitives only. Path-string ops (expand/dirname/
// basename/split) and stat-mode predicates live in lib/core/4.0/file.rb;
// they don't need C++. What stays here is the irreducible POSIX surface
// the Ruby side has to call through.

#ifndef FROZONE_FILE_INTRINSICS_HPP
#define FROZONE_FILE_INTRINSICS_HPP


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
inline BasicObject* intrinsic_os_stat(BasicObject* path) {
  struct stat st;
  return ::stat(fs_detail::str_of(path).c_str(), &st) == 0 ? fs_detail::stat_array(st) : nil_instance();
}

// lstat(2) — same shape as os_stat but does not follow symlinks.
inline BasicObject* intrinsic_os_lstat(BasicObject* path) {
  struct stat st;
  return ::lstat(fs_detail::str_of(path).c_str(), &st) == 0 ? fs_detail::stat_array(st) : nil_instance();
}

// access(2) — mode_bits is R_OK|W_OK|X_OK (any combination of 4/2/1).
inline BasicObject* intrinsic_os_access(BasicObject* path, BasicObject* mode_bits) {
  int m = static_cast<int>(static_cast<Integer*>(mode_bits)->raw_);
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), m) == 0);
}

// realpath(3) — returns canonicalised absolute path, or nil on failure
// (e.g. ENOENT). Ruby side translates nil into ENOENT.
inline BasicObject* intrinsic_os_realpath(BasicObject* path) {
  char buf[4096];
  char* r = ::realpath(fs_detail::str_of(path).c_str(), buf);
  return r ? new String(r, std::strlen(r)) : nil_instance();
}

// readlink(2) — nil on failure. Buffer sized for PATH_MAX.
inline BasicObject* intrinsic_os_readlink(BasicObject* path) {
  char buf[4096];
  ssize_t n = ::readlink(fs_detail::str_of(path).c_str(), buf, sizeof(buf));
  if (n < 0) return nil_instance();
  return new String(buf, static_cast<std::size_t>(n));
}

// euid/egid for owned?/grpowned? — separate from the eu*id intrinsics in
// process_intrinsics so File doesn't pull in Process namespace.
inline BasicObject* intrinsic_os_euid() {
  return new Integer(static_cast<int64_t>(::geteuid()));
}
inline BasicObject* intrinsic_os_egid() {
  return new Integer(static_cast<int64_t>(::getegid()));
}

// Whole-file slurp. Caller (File.read) handles encoding. Returns nil if
// the path can't be opened; the Ruby side maps that to Errno::ENOENT.
inline BasicObject* intrinsic_file_read(BasicObject* path) {
  std::ifstream f(fs_detail::str_of(path), std::ios::binary);
  if (!f.is_open()) return nil_instance();
  std::stringstream ss;
  ss << f.rdbuf();
  std::string s = ss.str();
  return new String(s.data(), s.size());
}

// ---- Mutating POSIX primitives -----------------------------------
// Each returns nil on errno failure; Ruby maps nil → the appropriate
// Errno::* via inspecting errno or trying again.

inline BasicObject* intrinsic_os_unlink(BasicObject* path) {
  return ::unlink(fs_detail::str_of(path).c_str()) == 0 ? true_instance() : nil_instance();
}

inline BasicObject* intrinsic_os_rename(BasicObject* from, BasicObject* to) {
  return ::rename(fs_detail::str_of(from).c_str(),
                  fs_detail::str_of(to).c_str()) == 0 ? true_instance() : nil_instance();
}

inline BasicObject* intrinsic_os_link(BasicObject* target, BasicObject* link) {
  return ::link(fs_detail::str_of(target).c_str(),
                fs_detail::str_of(link).c_str()) == 0 ? true_instance() : nil_instance();
}

inline BasicObject* intrinsic_os_symlink(BasicObject* target, BasicObject* link) {
  return ::symlink(fs_detail::str_of(target).c_str(),
                   fs_detail::str_of(link).c_str()) == 0 ? true_instance() : nil_instance();
}

inline BasicObject* intrinsic_os_chmod(BasicObject* path, BasicObject* mode) {
  mode_t m = static_cast<mode_t>(static_cast<Integer*>(mode)->raw_);
  return ::chmod(fs_detail::str_of(path).c_str(), m) == 0 ? true_instance() : nil_instance();
}

inline BasicObject* intrinsic_os_truncate(BasicObject* path, BasicObject* length) {
  off_t len = static_cast<off_t>(static_cast<Integer*>(length)->raw_);
  return ::truncate(fs_detail::str_of(path).c_str(), len) == 0 ? true_instance() : nil_instance();
}

// utimensat with AT_FDCWD; accepts nanosecond-precision atime/mtime.
// flags 0 follows symlinks; AT_SYMLINK_NOFOLLOW for lutime.
inline BasicObject* intrinsic_os_utimes(BasicObject* path,
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

inline BasicObject* intrinsic_os_mkfifo(BasicObject* path, BasicObject* mode) {
  mode_t m = static_cast<mode_t>(static_cast<Integer*>(mode)->raw_);
  return ::mkfifo(fs_detail::str_of(path).c_str(), m) == 0 ? true_instance() : nil_instance();
}

// umask sets+returns prior mask. nil arg → query (no change). Tricky
// because umask has no "query without change" form; emulate via
// set→reset.
inline BasicObject* intrinsic_os_umask(BasicObject* new_mask) {
  if (new_mask == nil_instance()) {
    mode_t prev = ::umask(0);
    ::umask(prev);
    return new Integer(static_cast<int64_t>(prev));
  }
  mode_t m = static_cast<mode_t>(static_cast<Integer*>(new_mask)->raw_);
  return new Integer(static_cast<int64_t>(::umask(m)));
}

inline BasicObject* intrinsic_os_fnmatch(BasicObject* pattern, BasicObject* path, BasicObject* flags) {
  int f = static_cast<int>(static_cast<Integer*>(flags)->raw_);
  return boxed_bool(
    ::fnmatch(fs_detail::str_of(pattern).c_str(),
              fs_detail::str_of(path).c_str(), f) == 0);
}
#endif  // FROZONE_FILE_INTRINSICS_HPP
