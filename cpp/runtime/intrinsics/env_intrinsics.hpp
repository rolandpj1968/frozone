// Env-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.
//
// Minimal surface: getenv/setenv/unsetenv + a single walk of POSIX
// `environ` returning an Array of [key, value] String pairs. All
// Hash-shape logic (keys, values, key?, value?, to_h, clear, …) lives
// in lib/core/4.0/env.rb on top of these four primitives.

#ifndef FROZONE_ENV_INTRINSICS_HPP
#define FROZONE_ENV_INTRINSICS_HPP


inline BasicObject* intrinsic_os_getenv(BasicObject* key) {
  const char* v = std::getenv(fs_detail::str_of(key).c_str());
  return v ? env_detail::string_of(v) : nil_instance();
}

inline BasicObject* intrinsic_os_setenv(BasicObject* key, BasicObject* value) {
  ::setenv(fs_detail::str_of(key).c_str(), fs_detail::str_of(value).c_str(), 1);
  return nil_instance();
}

inline BasicObject* intrinsic_os_unsetenv(BasicObject* key) {
  ::unsetenv(fs_detail::str_of(key).c_str());
  return nil_instance();
}

inline BasicObject* intrinsic_os_environ_pairs() {
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

#endif  // FROZONE_ENV_INTRINSICS_HPP
