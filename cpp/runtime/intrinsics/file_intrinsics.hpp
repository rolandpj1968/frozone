// File-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_FILE_INTRINSICS_HPP
#define FROZONE_FILE_INTRINSICS_HPP


inline BasicObject* intrinsic_file_expand_path(BasicObject* path, BasicObject* dir) {
  std::string _dir = (dir && dir != nil_instance()) ? fs_detail::str_of(dir) : "";
  return fs_detail::string_of(fs_detail::expand(fs_detail::str_of(path), _dir));
}

// File.dirname(path, level=1) — strip `level` trailing components.
// Pure std::string ops to avoid std::filesystem::path; see
// intrinsics.hpp::fs_detail::expand for the Boehm/libstdc++ rationale.
inline BasicObject* intrinsic_file_dirname(BasicObject* path, BasicObject* level) {
  int64_t lvl = 1;
  if (level && level != nil_instance()) {
    if (typeid(*level) == typeid(Integer)) lvl = static_cast<Integer*>(level)->raw_;
  }
  std::string s = fs_detail::str_of(path);
  while (lvl-- > 0 && !s.empty()) {
    auto slash = s.find_last_of('/');
    if (slash == std::string::npos) { s = ""; break; }
    if (slash == 0) { s = "/"; break; }
    s = s.substr(0, slash);
  }
  return fs_detail::string_of(s.empty() ? std::string(".") : s);
}

// File.basename(path, suffix=nil) — strip suffix when given (".rb",
// ".*" matches any extension).
inline BasicObject* intrinsic_file_basename(BasicObject* path, BasicObject* suffix) {
  std::string s = fs_detail::str_of(path);
  auto slash = s.find_last_of('/');
  std::string base = (slash == std::string::npos) ? s : s.substr(slash + 1);
  if (suffix && suffix != nil_instance()) {
    std::string sfx = fs_detail::str_of(suffix);
    if (sfx == ".*") {
      auto dot = base.find_last_of('.');
      if (dot != std::string::npos && dot > 0) base.erase(dot);
    } else if (sfx.size() < base.size() && base.compare(base.size() - sfx.size(), sfx.size(), sfx) == 0) {
      base.erase(base.size() - sfx.size());
    }
  }
  return fs_detail::string_of(base);
}

inline BasicObject* intrinsic_file_split(BasicObject* path) {
  std::string s = fs_detail::str_of(path);
  auto slash = s.find_last_of('/');
  std::string d, f;
  if (slash == std::string::npos) { d = "."; f = s; }
  else if (slash == 0)            { d = "/"; f = s.substr(1); }
  else                            { d = s.substr(0, slash); f = s.substr(slash + 1); }
  return new Array({static_cast<BasicObject*>(fs_detail::string_of(d)),
                    static_cast<BasicObject*>(fs_detail::string_of(f))});
}

inline BasicObject* intrinsic_file_exist(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0);
}

inline BasicObject* intrinsic_file_directory(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0 && S_ISDIR(st.st_mode));
}

inline BasicObject* intrinsic_file_file(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0 && S_ISREG(st.st_mode));
}

inline BasicObject* intrinsic_file_size(BasicObject* path) {
  struct stat st;
  if (::stat(fs_detail::str_of(path).c_str(), &st) != 0) return nil_instance();
  return static_cast<BasicObject*>(new Integer(static_cast<int64_t>(st.st_size)));
}

inline BasicObject* intrinsic_file_size_exact(BasicObject* path) {
  return intrinsic_file_size(path);
}

// realpath(3) — resolves symlinks for existing paths. If path doesn't
// exist, falls back to our lexically-normalised expand result.
inline BasicObject* intrinsic_file_realpath(BasicObject* path, BasicObject* dir) {
  std::string _dir = (dir && dir != nil_instance()) ? fs_detail::str_of(dir) : "";
  std::string joined = fs_detail::expand(fs_detail::str_of(path), _dir);
  char buf[4096];
  char* r = ::realpath(joined.c_str(), buf);
  return fs_detail::string_of(r ? std::string(r) : joined);
}

// MRI's weakly_canonical: canonicalise the longest existing prefix,
// append the rest lexically. We approximate by trying realpath on
// the full path; on failure (typically because a tail component
// doesn't exist) we return the lexically-normalised expand result.
// Good enough for the load-path lookups that hit this in practice.
inline BasicObject* intrinsic_file_realdirpath(BasicObject* path, BasicObject* dir) {
  return intrinsic_file_realpath(path, dir);
}

inline BasicObject* intrinsic_file_read(BasicObject* path) {
  std::ifstream f(fs_detail::str_of(path), std::ios::binary);
  if (!f.is_open()) return nil_instance();
  std::stringstream ss;
  ss << f.rdbuf();
  std::string s = ss.str();
  return new String(s.data(), s.size());
}

inline BasicObject* intrinsic_file_readable(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), R_OK) == 0);
}
inline BasicObject* intrinsic_file_readable_real(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), R_OK) == 0);
}
inline BasicObject* intrinsic_file_writable(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), W_OK) == 0);
}
inline BasicObject* intrinsic_file_writable_real(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), W_OK) == 0);
}
inline BasicObject* intrinsic_file_executable(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), X_OK) == 0);
}
inline BasicObject* intrinsic_file_executable_real(BasicObject* path) {
  return boxed_bool(::access(fs_detail::str_of(path).c_str(), X_OK) == 0);
}
inline BasicObject* intrinsic_file_owned(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0 && st.st_uid == ::geteuid());
}
inline BasicObject* intrinsic_file_grpowned(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0 && st.st_gid == ::getegid());
}
inline BasicObject* intrinsic_file_zero(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0 && st.st_size == 0);
}
inline BasicObject* intrinsic_file_chardev(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_IFCHR)); }
inline BasicObject* intrinsic_file_blockdev(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_IFBLK)); }
inline BasicObject* intrinsic_file_pipe(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_IFIFO)); }
inline BasicObject* intrinsic_file_socket(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_IFSOCK)); }
inline BasicObject* intrinsic_file_symlink(BasicObject* path) {
  struct stat st;
  return boxed_bool(::lstat(fs_detail::str_of(path).c_str(), &st) == 0 && S_ISLNK(st.st_mode));
}
inline BasicObject* intrinsic_file_setuid(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_ISUID)); }
inline BasicObject* intrinsic_file_setgid(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_ISGID)); }
inline BasicObject* intrinsic_file_sticky(BasicObject* path) { return boxed_bool(fs_detail::stat_check(path, S_ISVTX)); }
inline BasicObject* intrinsic_file_identical(BasicObject* a, BasicObject* b) {
  struct stat sa, sb;
  if (::stat(fs_detail::str_of(a).c_str(), &sa) != 0) return false_instance();
  if (::stat(fs_detail::str_of(b).c_str(), &sb) != 0) return false_instance();
  return boxed_bool(sa.st_dev == sb.st_dev && sa.st_ino == sb.st_ino);
}
#endif  // FROZONE_FILE_INTRINSICS_HPP
