// File-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_FILE_INTRINSICS_HPP
#define FROZONE_FILE_INTRINSICS_HPP


inline BasicObject* intrinsic_file_expand_path(BasicObject* path, BasicObject* dir) {
  std::string _dir = (dir && dir != nil_instance()) ? fs_detail::str_of(dir) : "";
  return fs_detail::string_of(fs_detail::expand(fs_detail::str_of(path), _dir));
}

// File.dirname(path, level=1) — strip `level` trailing components.
inline BasicObject* intrinsic_file_dirname(BasicObject* path, BasicObject* level) {
  int64_t lvl = 1;
  if (level && level != nil_instance()) {
    if (auto* i = dynamic_cast<Integer*>(level)) lvl = i->raw_;
  }
  std::filesystem::path p(fs_detail::str_of(path));
  while (lvl-- > 0 && p.has_parent_path()) p = p.parent_path();
  auto d = p.string();
  return fs_detail::string_of(d.empty() ? std::string(".") : d);
}

// File.basename(path, suffix=nil) — strip suffix when given (".rb",
// ".*" matches any extension).
inline BasicObject* intrinsic_file_basename(BasicObject* path, BasicObject* suffix) {
  std::filesystem::path p(fs_detail::str_of(path));
  std::string base = p.filename().string();
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
  std::filesystem::path p(fs_detail::str_of(path));
  auto d = p.parent_path().string();
  if (d.empty()) d = ".";
  return new Array({static_cast<BasicObject*>(fs_detail::string_of(d)),
                    static_cast<BasicObject*>(fs_detail::string_of(p.filename().string()))});
}

inline BasicObject* intrinsic_file_exist(BasicObject* path) {
  std::error_code ec;
  return boxed_bool(std::filesystem::exists(fs_detail::str_of(path), ec));
}

inline BasicObject* intrinsic_file_directory(BasicObject* path) {
  std::error_code ec;
  return boxed_bool(std::filesystem::is_directory(fs_detail::str_of(path), ec));
}

inline BasicObject* intrinsic_file_file(BasicObject* path) {
  std::error_code ec;
  return boxed_bool(std::filesystem::is_regular_file(fs_detail::str_of(path), ec));
}

inline BasicObject* intrinsic_file_size(BasicObject* path) {
  std::error_code ec;
  auto sz = std::filesystem::file_size(fs_detail::str_of(path), ec);
  return ec ? nil_instance() : static_cast<BasicObject*>(new Integer(static_cast<int64_t>(sz)));
}

inline BasicObject* intrinsic_file_size_exact(BasicObject* path) {
  return intrinsic_file_size(path);
}

inline BasicObject* intrinsic_file_realpath(BasicObject* path, BasicObject* dir) {
  std::string _dir = (dir && dir != nil_instance()) ? fs_detail::str_of(dir) : "";
  std::string joined = fs_detail::expand(fs_detail::str_of(path), _dir);
  std::error_code ec;
  auto canon = std::filesystem::canonical(joined, ec);
  return ec ? fs_detail::string_of(joined) : fs_detail::string_of(canon.string());
}

inline BasicObject* intrinsic_file_realdirpath(BasicObject* path, BasicObject* dir) {
  std::string _dir = (dir && dir != nil_instance()) ? fs_detail::str_of(dir) : "";
  std::string joined = fs_detail::expand(fs_detail::str_of(path), _dir);
  std::error_code ec;
  auto canon = std::filesystem::weakly_canonical(joined, ec);
  return ec ? fs_detail::string_of(joined) : fs_detail::string_of(canon.string());
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
