// Dir-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_DIR_INTRINSICS_HPP
#define FROZONE_DIR_INTRINSICS_HPP


// ---- Dir -----------------------------------------------------------
//
// Most of these are <filesystem> one-liners. dir_open/read/close/seek
// hold a per-instance DIR* — the Ruby wrapper guarantees the receiver
// is a Dir, but we don't yet have a place to hang the DIR* off the
// generated `Dir` struct (no @dir_handle ivar). For now those abort
// loudly. dir_glob, dir_chdir, dir_pwd, dir_home, dir_entries,
// dir_mkdir/rmdir, dir_exist/empty cover the path-based queries that
// frozone itself uses.

inline BasicObject* intrinsic_dir_pwd() {
  return fs_detail::string_of(std::filesystem::current_path().string());
}

inline BasicObject* intrinsic_dir_chdir(BasicObject* path, BasicObject* block) {
  std::error_code ec;
  // path == nil → Dir.chdir restores HOME; block form chdirs in,
  // yields, then restores. We only support path-only no-block here.
  if (block != nil_instance()) {
    std::fprintf(stderr, "[box-first] dir_chdir with block not yet supported\n");
    std::abort();
  }
  if (path == nil_instance()) {
    const char* h = std::getenv("HOME");
    if (h) std::filesystem::current_path(h, ec);
  } else {
    std::filesystem::current_path(fs_detail::str_of(path), ec);
  }
  return new Integer(0);
}

inline BasicObject* intrinsic_dir_home(BasicObject* user) {
  if (user == nil_instance()) {
    const char* h = std::getenv("HOME");
    return h ? fs_detail::string_of(h) : nil_instance();
  }
  // Per-user lookup needs <pwd.h> — defer until needed.
  std::fprintf(stderr, "[box-first] dir_home(user) not yet supported (per-user pwd lookup)\n");
  std::abort();
}

inline BasicObject* intrinsic_dir_entries(BasicObject* path) {
  Array* arr = new Array();
  std::error_code ec;
  // "." and ".." come first to match MRI ordering.
  arr->data.push_back(fs_detail::string_of("."));
  arr->data.push_back(fs_detail::string_of(".."));
  for (auto& e : std::filesystem::directory_iterator(fs_detail::str_of(path), ec)) {
    arr->data.push_back(fs_detail::string_of(e.path().filename().string()));
  }
  return arr;
}

inline BasicObject* intrinsic_dir_glob(BasicObject* pattern, BasicObject* /*flags*/, BasicObject* /*base*/, BasicObject* /*sort*/) {
  // Minimal glob — supports simple `*` and literal paths only.
  // MRI's glob has many flags (FNM_DOTMATCH, FNM_CASEFOLD, etc.) that
  // we ignore for now; real bash-style glob expansion is its own
  // project. Sufficient for `Dir["*.rb"]` and `Dir["lib/**/*.rb"]`
  // when the pattern is a single literal-or-star segment. More
  // complex patterns abort with a flag asking the user to file an issue.
  std::string pat = fs_detail::str_of(pattern);
  Array* arr = new Array();
  // Catch the "**" recursive glob upfront.
  if (pat.find("**") != std::string::npos) {
    // Split pattern at **/* into prefix + suffix-extension.
    std::size_t star = pat.find("**");
    std::string prefix = pat.substr(0, star);
    if (!prefix.empty() && prefix.back() == '/') prefix.pop_back();
    if (prefix.empty()) prefix = ".";
    std::string suffix = pat.substr(star + 2);  // skip "**"
    if (!suffix.empty() && suffix.front() == '/') suffix.erase(0, 1);
    // Build an extension matcher: last dot-segment.
    std::string ext;
    if (auto dot = suffix.rfind('.'); dot != std::string::npos) ext = suffix.substr(dot);
    std::error_code ec;
    for (auto it = std::filesystem::recursive_directory_iterator(prefix, ec);
         it != std::filesystem::recursive_directory_iterator(); it.increment(ec)) {
      if (ec) break;
      if (!it->is_regular_file()) continue;
      std::string s = it->path().string();
      if (ext.empty() || (s.size() >= ext.size() && s.compare(s.size() - ext.size(), ext.size(), ext) == 0)) {
        arr->data.push_back(fs_detail::string_of(s));
      }
    }
    return arr;
  }
  // Single-segment * glob.
  std::size_t slash = pat.rfind('/');
  std::string dir = (slash == std::string::npos) ? "." : pat.substr(0, slash);
  std::string base = (slash == std::string::npos) ? pat : pat.substr(slash + 1);
  std::size_t star = base.find('*');
  if (star == std::string::npos) {
    // Literal — exists check.
    if (std::filesystem::exists(pat)) arr->data.push_back(fs_detail::string_of(pat));
    return arr;
  }
  std::string prefix = base.substr(0, star);
  std::string suffix = base.substr(star + 1);
  std::error_code ec;
  for (auto& e : std::filesystem::directory_iterator(dir, ec)) {
    std::string n = e.path().filename().string();
    if (n.size() < prefix.size() + suffix.size()) continue;
    if (n.compare(0, prefix.size(), prefix) != 0) continue;
    if (n.compare(n.size() - suffix.size(), suffix.size(), suffix) != 0) continue;
    arr->data.push_back(fs_detail::string_of((dir == "." ? n : dir + "/" + n)));
  }
  return arr;
}

inline BasicObject* intrinsic_dir_mkdir(BasicObject* path, BasicObject* /*perm*/) {
  std::error_code ec;
  std::filesystem::create_directory(fs_detail::str_of(path), ec);
  if (ec) {
    std::fprintf(stderr, "[box-first] dir_mkdir failed: %s\n", ec.message().c_str());
    std::abort();
  }
  return new Integer(0);
}

inline BasicObject* intrinsic_dir_rmdir(BasicObject* path) {
  std::error_code ec;
  std::filesystem::remove(fs_detail::str_of(path), ec);
  return new Integer(0);
}

inline BasicObject* intrinsic_dir_exist(BasicObject* path) {
  std::error_code ec;
  return boxed_bool(std::filesystem::is_directory(fs_detail::str_of(path), ec));
}

inline BasicObject* intrinsic_dir_empty(BasicObject* path) {
  std::error_code ec;
  return boxed_bool(std::filesystem::is_empty(fs_detail::str_of(path), ec));
}

// Per-instance DIR* state — the generated Dir struct has no slot
// for it, so attempting to use these from Ruby aborts. Listed for
// completeness of HPP_INTRINSICS coverage.
inline BasicObject* intrinsic_dir_open(BasicObject* /*path*/) {
  std::fprintf(stderr, "[box-first] dir_open not yet supported (no DIR* slot on Dir)\n");
  std::abort();
}
inline BasicObject* intrinsic_dir_close(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] dir_close not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_dir_read(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] dir_read not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_dir_seek(BasicObject* /*obj*/, BasicObject* /*pos*/) {
  std::fprintf(stderr, "[box-first] dir_seek not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_dir_rewind(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] dir_rewind not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_dir_fileno(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] dir_fileno not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_dir_for_fd(BasicObject* /*fd*/) {
  std::fprintf(stderr, "[box-first] dir_for_fd not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_dir_fchdir(BasicObject* /*fd*/, BasicObject* /*block*/) {
  std::fprintf(stderr, "[box-first] dir_fchdir not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_dir_chroot(BasicObject* /*path*/) {
  std::fprintf(stderr, "[box-first] dir_chroot not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_dir_mktmpdir(BasicObject* /*prefix*/, BasicObject* /*block*/) {
  std::fprintf(stderr, "[box-first] dir_mktmpdir not yet supported\n");
  std::abort();
}
#endif  // FROZONE_DIR_INTRINSICS_HPP
