// Dir-category intrinsic definitions. Declarations live in
// dir_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "dir_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Dir -----------------------------------------------------------
//
// POSIX opendir/readdir/stat instead of std::filesystem — the latter
// crashes at -O2 when libstdc++.so's internal free() runs on a Boehm-
// allocated buffer (see box_first.hpp for the full rationale).
// dir_open/read/close/seek hold a per-instance DIR* off the generated
// `Dir` struct (no @dir_handle ivar yet) so those abort loudly.
// dir_glob, dir_chdir, dir_pwd, dir_home, dir_entries, dir_mkdir/rmdir,
// dir_exist/empty cover the path-based queries that frozone itself uses.

BasicObject* intrinsic_dir_pwd() {
  char cwd[4096];
  return fs_detail::string_of(::getcwd(cwd, sizeof(cwd)) ? std::string(cwd) : std::string());
}

BasicObject* intrinsic_dir_chdir(BasicObject* path, BasicObject* block) {
  // path == nil → Dir.chdir restores HOME; block form chdirs in,
  // yields, then restores. We only support path-only no-block here.
  if (block != nil_instance()) {
    std::fprintf(stderr, "[box-first] dir_chdir with block not yet supported\n");
    std::abort();
  }
  std::string target;
  if (path == nil_instance()) {
    const char* h = std::getenv("HOME");
    if (!h) return new Integer(0);
    target = h;
  } else {
    target = fs_detail::str_of(path);
  }
  (void)::chdir(target.c_str());
  return new Integer(0);
}

BasicObject* intrinsic_dir_home(BasicObject* user) {
  if (user == nil_instance()) {
    const char* h = std::getenv("HOME");
    return h ? fs_detail::string_of(h) : nil_instance();
  }
  // Per-user lookup needs <pwd.h> — defer until needed.
  std::fprintf(stderr, "[box-first] dir_home(user) not yet supported (per-user pwd lookup)\n");
  std::abort();
}

BasicObject* intrinsic_dir_entries(BasicObject* path) {
  Array* arr = new Array();
  // "." and ".." come first to match MRI ordering.
  arr->data.push_back(fs_detail::string_of("."));
  arr->data.push_back(fs_detail::string_of(".."));
  DIR* d = ::opendir(fs_detail::str_of(path).c_str());
  if (!d) return arr;
  while (struct dirent* e = ::readdir(d)) {
    std::string n = e->d_name;
    if (n == "." || n == "..") continue;
    arr->data.push_back(fs_detail::string_of(n));
  }
  ::closedir(d);
  return arr;
}

namespace fs_detail {
  // Recursive directory walk via opendir/readdir. Calls `visit(path, is_dir)`
  // for every entry (skipping . and ..). is_dir uses d_type when available,
  // falling back to stat — needed because some filesystems return DT_UNKNOWN.
  template<typename F>
  inline void walk_recursive(const std::string& root, F visit) {
    DIR* d = ::opendir(root.c_str());
    if (!d) return;
    while (struct dirent* e = ::readdir(d)) {
      std::string n = e->d_name;
      if (n == "." || n == "..") continue;
      std::string full = root + "/" + n;
      bool is_dir;
      if (e->d_type == DT_DIR) is_dir = true;
      else if (e->d_type == DT_REG) is_dir = false;
      else {
        struct stat st;
        is_dir = (::stat(full.c_str(), &st) == 0 && S_ISDIR(st.st_mode));
      }
      visit(full, is_dir);
      if (is_dir) walk_recursive(full, visit);
    }
    ::closedir(d);
  }
}

BasicObject* intrinsic_dir_glob(BasicObject* pattern, BasicObject* /*flags*/, BasicObject* /*base*/, BasicObject* /*sort*/) {
  // Minimal glob — supports simple `*` and literal paths only. MRI's
  // glob has many flags (FNM_DOTMATCH, FNM_CASEFOLD, etc.) that we
  // ignore; real bash-style glob expansion is its own project.
  // Sufficient for `Dir["*.rb"]` and `Dir["lib/**/*.rb"]` when the
  // pattern is a single literal-or-star segment.
  std::string pat = fs_detail::str_of(pattern);
  Array* arr = new Array();
  // Catch the "**" recursive glob upfront.
  if (pat.find("**") != std::string::npos) {
    std::size_t star = pat.find("**");
    std::string prefix = pat.substr(0, star);
    if (!prefix.empty() && prefix.back() == '/') prefix.pop_back();
    if (prefix.empty()) prefix = ".";
    std::string suffix = pat.substr(star + 2);
    if (!suffix.empty() && suffix.front() == '/') suffix.erase(0, 1);
    std::string ext;
    if (auto dot = suffix.rfind('.'); dot != std::string::npos) ext = suffix.substr(dot);
    fs_detail::walk_recursive(prefix, [&](const std::string& p, bool is_dir) {
      if (is_dir) return;
      if (ext.empty() || (p.size() >= ext.size() && p.compare(p.size() - ext.size(), ext.size(), ext) == 0)) {
        arr->data.push_back(fs_detail::string_of(p));
      }
    });
    return arr;
  }
  // Single-segment * glob.
  std::size_t slash = pat.rfind('/');
  std::string dir = (slash == std::string::npos) ? "." : pat.substr(0, slash);
  std::string base = (slash == std::string::npos) ? pat : pat.substr(slash + 1);
  std::size_t star = base.find('*');
  if (star == std::string::npos) {
    // Literal — exists check.
    struct stat st;
    if (::stat(pat.c_str(), &st) == 0) arr->data.push_back(fs_detail::string_of(pat));
    return arr;
  }
  std::string prefix = base.substr(0, star);
  std::string suffix = base.substr(star + 1);
  DIR* d = ::opendir(dir.c_str());
  if (!d) return arr;
  while (struct dirent* e = ::readdir(d)) {
    std::string n = e->d_name;
    if (n == "." || n == "..") continue;
    if (n.size() < prefix.size() + suffix.size()) continue;
    if (n.compare(0, prefix.size(), prefix) != 0) continue;
    if (n.compare(n.size() - suffix.size(), suffix.size(), suffix) != 0) continue;
    arr->data.push_back(fs_detail::string_of((dir == "." ? n : dir + "/" + n)));
  }
  ::closedir(d);
  return arr;
}

BasicObject* intrinsic_dir_mkdir(BasicObject* path, BasicObject* /*perm*/) {
  if (::mkdir(fs_detail::str_of(path).c_str(), 0777) != 0) {
    std::fprintf(stderr, "[box-first] dir_mkdir failed: %s\n", std::strerror(errno));
    std::abort();
  }
  return new Integer(0);
}

BasicObject* intrinsic_dir_rmdir(BasicObject* path) {
  ::rmdir(fs_detail::str_of(path).c_str());
  return new Integer(0);
}

BasicObject* intrinsic_dir_exist(BasicObject* path) {
  struct stat st;
  return boxed_bool(::stat(fs_detail::str_of(path).c_str(), &st) == 0 && S_ISDIR(st.st_mode));
}

BasicObject* intrinsic_dir_empty(BasicObject* path) {
  DIR* d = ::opendir(fs_detail::str_of(path).c_str());
  if (!d) return false_instance();
  bool empty = true;
  while (struct dirent* e = ::readdir(d)) {
    std::string n = e->d_name;
    if (n != "." && n != "..") { empty = false; break; }
  }
  ::closedir(d);
  return boxed_bool(empty);
}

// Per-instance DIR* state — the generated Dir struct has no slot
// for it, so attempting to use these from Ruby aborts. Listed for
// completeness of HPP_INTRINSICS coverage.
BasicObject* intrinsic_dir_open(BasicObject* /*path*/) {
  std::fprintf(stderr, "[box-first] dir_open not yet supported (no DIR* slot on Dir)\n");
  std::abort();
}

BasicObject* intrinsic_dir_close(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] dir_close not yet supported\n");
  std::abort();
}

BasicObject* intrinsic_dir_read(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] dir_read not yet supported\n");
  std::abort();
}

BasicObject* intrinsic_dir_seek(BasicObject* /*obj*/, BasicObject* /*pos*/) {
  std::fprintf(stderr, "[box-first] dir_seek not yet supported\n");
  std::abort();
}

BasicObject* intrinsic_dir_rewind(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] dir_rewind not yet supported\n");
  std::abort();
}

BasicObject* intrinsic_dir_fileno(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] dir_fileno not yet supported\n");
  std::abort();
}

BasicObject* intrinsic_dir_for_fd(BasicObject* /*fd*/) {
  std::fprintf(stderr, "[box-first] dir_for_fd not yet supported\n");
  std::abort();
}

BasicObject* intrinsic_dir_fchdir(BasicObject* /*fd*/, BasicObject* /*block*/) {
  std::fprintf(stderr, "[box-first] dir_fchdir not yet supported\n");
  std::abort();
}

BasicObject* intrinsic_dir_chroot(BasicObject* /*path*/) {
  std::fprintf(stderr, "[box-first] dir_chroot not yet supported\n");
  std::abort();
}

// `Intrinsics.os_mkdtemp(template)` — thin POSIX wrapper. `template`
// must end in "XXXXXX"; mkdtemp(3) overwrites those 6 chars with a
// unique suffix and returns the resulting path. Ruby-side
// Dir.mktmpdir (core/4.0/dir.rb) handles template construction +
// block + cleanup; this is just the OS syscall.
BasicObject* intrinsic_os_mkdtemp(BasicObject* template_obj) {
  std::string tmpl = fs_detail::str_of(template_obj);
  std::vector<char> buf(tmpl.begin(), tmpl.end());
  buf.push_back('\0');
  char* result = ::mkdtemp(buf.data());
  if (!result) {
    std::fprintf(stderr, "[box-first] os_mkdtemp(%s): errno %d\n", tmpl.c_str(), errno);
    std::abort();
  }
  return fs_detail::string_of(std::string(result));
}

}  // namespace Ruby
