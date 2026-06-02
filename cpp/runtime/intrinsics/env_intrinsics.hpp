// Env-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_ENV_INTRINSICS_HPP
#define FROZONE_ENV_INTRINSICS_HPP


inline BasicObject* intrinsic_env_get(BasicObject* key) {
  const char* v = std::getenv(fs_detail::str_of(key).c_str());
  return v ? env_detail::string_of(v) : nil_instance();
}

inline BasicObject* intrinsic_env_set(BasicObject* key, BasicObject* value) {
  std::string k = fs_detail::str_of(key);
  if (value == nil_instance()) {
    ::unsetenv(k.c_str());
    return nil_instance();
  }
  ::setenv(k.c_str(), fs_detail::str_of(value).c_str(), 1);
  return value;
}

inline BasicObject* intrinsic_env_delete(BasicObject* key) {
  std::string k = fs_detail::str_of(key);
  const char* v = std::getenv(k.c_str());
  if (!v) return nil_instance();
  BasicObject* old = env_detail::string_of(v);
  ::unsetenv(k.c_str());
  return old;
}

inline BasicObject* intrinsic_env_key_q(BasicObject* key) {
  return boxed_bool(std::getenv(fs_detail::str_of(key).c_str()) != nullptr);
}

inline BasicObject* intrinsic_env_value_q(BasicObject* value) {
  std::string v = fs_detail::str_of(value);
  for (char** e = environ; *e; ++e) {
    const char* eq = std::strchr(*e, '=');
    if (!eq) continue;
    if (v.size() == std::strlen(eq + 1) && std::memcmp(eq + 1, v.data(), v.size()) == 0) {
      return true_instance();
    }
  }
  return false_instance();
}

inline BasicObject* intrinsic_env_key(BasicObject* value) {
  std::string v = fs_detail::str_of(value);
  for (char** e = environ; *e; ++e) {
    const char* eq = std::strchr(*e, '=');
    if (!eq) continue;
    if (v.size() == std::strlen(eq + 1) && std::memcmp(eq + 1, v.data(), v.size()) == 0) {
      return env_detail::string_of(*e, static_cast<std::size_t>(eq - *e));
    }
  }
  return nil_instance();
}

inline BasicObject* intrinsic_env_keys() {
  Array* arr = new Array();
  for (char** e = environ; *e; ++e) {
    const char* eq = std::strchr(*e, '=');
    if (!eq) continue;
    arr->data.push_back(env_detail::string_of(*e, static_cast<std::size_t>(eq - *e)));
  }
  return arr;
}

inline BasicObject* intrinsic_env_values() {
  Array* arr = new Array();
  for (char** e = environ; *e; ++e) {
    const char* eq = std::strchr(*e, '=');
    if (!eq) continue;
    arr->data.push_back(env_detail::string_of(eq + 1));
  }
  return arr;
}

inline BasicObject* intrinsic_env_size() {
  std::int64_t n = 0;
  for (char** e = environ; *e; ++e) ++n;
  return new Integer(n);
}

inline BasicObject* intrinsic_env_pairs() {
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

inline BasicObject* intrinsic_env_to_hash() {
  Hash* h = new Hash();
  for (char** e = environ; *e; ++e) {
    const char* eq = std::strchr(*e, '=');
    if (!eq) continue;
    BasicObject* k = env_detail::string_of(*e, static_cast<std::size_t>(eq - *e));
    BasicObject* v = env_detail::string_of(eq + 1);
    h->put(k, v);
  }
  return h;
}

inline BasicObject* intrinsic_env_clear() {
  // unsetenv invalidates environ entries while iterating, so snapshot
  // keys first.
  std::vector<std::string> keys;
  for (char** e = environ; *e; ++e) {
    const char* eq = std::strchr(*e, '=');
    if (!eq) continue;
    keys.emplace_back(*e, static_cast<std::size_t>(eq - *e));
  }
  for (auto& k : keys) ::unsetenv(k.c_str());
  return nil_instance();
}
#endif  // FROZONE_ENV_INTRINSICS_HPP
