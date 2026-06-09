// File-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.
//
// Scope: minimal OS primitives only. Path-string ops (expand/dirname/
// basename/split) and stat-mode predicates live in lib/core/4.0/file.rb;
// they don't need C++. What stays here is the irreducible POSIX surface
// the Ruby side has to call through.

#ifndef FROZONE_FILE_INTRINSICS_HPP
#define FROZONE_FILE_INTRINSICS_HPP


// stat(2) — returns nil on failure, else Array
//   [mode, size, uid, gid, dev, ino]
// Field order is mirrored in lib/core/4.0/file.rb (OS_STAT_*).
inline BasicObject* intrinsic_os_stat(BasicObject* path) {
  struct stat st;
  if (::stat(fs_detail::str_of(path).c_str(), &st) != 0) return nil_instance();
  return new Array({
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_mode))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_size))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_uid))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_gid))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_dev))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_ino))),
  });
}

// lstat(2) — same shape as os_stat but does not follow symlinks.
inline BasicObject* intrinsic_os_lstat(BasicObject* path) {
  struct stat st;
  if (::lstat(fs_detail::str_of(path).c_str(), &st) != 0) return nil_instance();
  return new Array({
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_mode))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_size))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_uid))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_gid))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_dev))),
    static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_ino))),
  });
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
#endif  // FROZONE_FILE_INTRINSICS_HPP
