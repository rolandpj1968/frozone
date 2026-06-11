// Env-category intrinsic definitions. Declarations live in
// env_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "env_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

namespace env_detail {
  inline BasicObject* string_of(const char* s, std::size_t n) {
    return new String(s, n);
  }
  inline BasicObject* string_of(const char* s) { return string_of(s, std::strlen(s)); }
}

BasicObject* intrinsic_os_getenv(BasicObject* key) {
  const char* v = std::getenv(fs_detail::str_of(key).c_str());
  return v ? env_detail::string_of(v) : nil_instance();
}

BasicObject* intrinsic_os_setenv(BasicObject* key, BasicObject* value) {
  ::setenv(fs_detail::str_of(key).c_str(), fs_detail::str_of(value).c_str(), 1);
  return nil_instance();
}

BasicObject* intrinsic_os_unsetenv(BasicObject* key) {
  ::unsetenv(fs_detail::str_of(key).c_str());
  return nil_instance();
}

BasicObject* intrinsic_os_environ_pairs() {
  Array* arr = new Array();
  for (char** e = environ; *e; ++e) {
    const char* eq = std::strchr(*e, '=');
    if (!eq) continue;
    Array* pair = new Array();
    pair->data.push_back(env_detail::string_of(*e, static_cast<std::size_t>(eq - *e)));
    pair->data.push_back(env_detail::string_of(eq + 1));
    arr->data.push_back(pair);
  }
  return arr;
}


}  // namespace Ruby
