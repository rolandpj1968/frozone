// Frozone C++ runtime — shared between all AOT-compiled Ruby programs.
// Generated from lib/frozone/compiler/cpp_emitter.rb; hand-edit for now.
// Single-header library: #include this in every generated .cpp.

#ifndef FROZONE_RUNTIME_HPP
#define FROZONE_RUNTIME_HPP

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <memory>
#include <type_traits>
#include <charconv>
#include <cinttypes>
#include <vector>
#include <list>
#include <unordered_map>
#include <variant>
#include <optional>

class RubyString {
public:
  // Ruby-semantic byte string with UTF-8 / BINARY encoding awareness.
  // .length counts UTF-8 codepoints when tagged UTF-8; raw bytes
  // when tagged BINARY. Encoding promotion on << matches MRI:
  // BINARY receiver + UTF-8 non-ASCII rhs flips receiver to UTF-8.
  enum Enc { UTF8 = 0, BINARY = 1 };
  std::vector<uint8_t> bytes;
  Enc enc = UTF8;
  mutable int64_t length_cache = -1;  // -1 = not yet computed

  RubyString() = default;
  RubyString(const char* s) { if (s) { size_t n = strlen(s); bytes.assign(s, s + n); } }
  RubyString(const char* s, size_t n) { bytes.assign(s, s + n); }
  RubyString(const char* s, size_t n, Enc e) : enc(e) { bytes.assign(s, s + n); }

  int64_t bytesize() const { return (int64_t)bytes.size(); }
  // .length — O(n) first call (UTF-8 codepoint scan), O(1) cached;
  // BINARY strings: bytesize.
  int64_t length() const {
    if (enc == BINARY) return (int64_t)bytes.size();
    if (length_cache < 0) {
      int64_t n = 0;
      for (auto b : bytes) if ((b & 0xC0) != 0x80) n++;
      length_cache = n;
    }
    return length_cache;
  }
  int64_t size() const { return length(); }
  int64_t len() const { return length(); }  // legacy; emitter targets this
  bool has_non_ascii() const {
    for (auto b : bytes) if (b >= 0x80) return true;
    return false;
  }

  int64_t get_byte(int64_t i) const { return (i >= 0 && i < (int64_t)bytes.size()) ? (int64_t)bytes[i] : 0; }
  void set_byte(int64_t i, int64_t v) { if (i >= 0 && i < (int64_t)bytes.size()) { bytes[i] = (uint8_t)(v & 0xff); length_cache = -1; } }
  RubyString dup_() const { return *this; }
  int64_t ord() const { return bytes.empty() ? 0 : (int64_t)bytes[0]; }
  RubyString operator[](int64_t i) const {
    if (i < 0 || i >= (int64_t)bytes.size()) return RubyString();
    return RubyString((const char*)&bytes[i], 1);
  }
  // `.b` — return a copy re-tagged as BINARY.
  RubyString b() const { RubyString c(*this); c.enc = BINARY; c.length_cache = -1; return c; }

  RubyString& operator<<(const RubyString& o) {
    // MRI encoding promotion: BINARY + UTF-8 non-ASCII → UTF-8.
    if (enc == BINARY && o.enc == UTF8 && o.has_non_ascii()) enc = UTF8;
    bytes.insert(bytes.end(), o.bytes.begin(), o.bytes.end());
    length_cache = -1;
    return *this;
  }
  RubyString& operator<<(const char* s) {
    if (s) { size_t n = strlen(s); bytes.insert(bytes.end(), s, s + n); length_cache = -1; }
    return *this;
  }
  RubyString operator+(const RubyString& o) const { RubyString r(*this); r << o; return r; }

  bool operator==(const RubyString& o) const { return bytes == o.bytes; }
  bool operator!=(const RubyString& o) const { return bytes != o.bytes; }
  bool operator<(const RubyString& o) const { return bytes < o.bytes; }
  bool operator<=(const RubyString& o) const { return bytes <= o.bytes; }
  bool operator>(const RubyString& o) const { return bytes > o.bytes; }
  bool operator>=(const RubyString& o) const { return bytes >= o.bytes; }
};
using Ruby_String = RubyString;

// ---------------------------------------------------------------------
// RubySymbol — interned string. Ruby symbols with the same text are the
// same object; comparison is O(1). We intern via a process-wide map of
// string → stable char*. RubySymbol stores the interned pointer;
// equality is pointer-equality.
// ---------------------------------------------------------------------
class RubySymbol {
public:
  const char* name = nullptr;  // interned, null-terminated

  RubySymbol() = default;
  explicit RubySymbol(const char* n) : name(n) {}  // pre-interned
  bool operator==(const RubySymbol& o) const { return name == o.name; }
  bool operator!=(const RubySymbol& o) const { return name != o.name; }
};

// Interning table — static, leaks at shutdown (fine for AOT programs).
// Uses a map from std::string (because we hash the text) to the owned
// interned strdup'd char*. Subsequent sym() calls with the same text
// return the same pointer.
inline RubySymbol ruby_sym(const char* s) {
  static std::unordered_map<std::string, const char*> interned;
  auto it = interned.find(s);
  if (it != interned.end()) return RubySymbol(it->second);
  char* copy = strdup(s);
  interned.emplace(s, copy);
  return RubySymbol(copy);
}

// std::hash specialisation so RubySymbol works as a key.
namespace std {
  template<> struct hash<RubySymbol> {
    size_t operator()(const RubySymbol& s) const noexcept {
      // Hash the pointer (works because interning guarantees uniqueness).
      return std::hash<const void*>{}(s.name);
    }
  };
}

// ---------------------------------------------------------------------
// RubyHash<K, V> — insertion-ordered map. O(1) insert / lookup / delete.
// Under the hood: std::list for order + std::unordered_map storing the
// value alongside a stable iterator into the list.
// Copy semantics: deep. Copying rebuilds list iterators in the map.
// ---------------------------------------------------------------------
template<typename K, typename V>
class RubyHash {
public:
  using ListType = std::list<K>;
  using MapEntry = std::pair<V, typename ListType::iterator>;

  ListType order;
  std::unordered_map<K, MapEntry> data;

  RubyHash() = default;

  // Copy ctor: rebuild the list, rebuild the map pointing at the new list.
  RubyHash(const RubyHash& o) {
    for (const auto& k : o.order) {
      order.push_back(k);
      auto it = std::prev(order.end());
      auto src = o.data.find(k);
      data.emplace(k, MapEntry{src->second.first, it});
    }
  }
  RubyHash& operator=(const RubyHash& o) {
    if (this == &o) return *this;
    order.clear(); data.clear();
    for (const auto& k : o.order) {
      order.push_back(k);
      auto it = std::prev(order.end());
      auto src = o.data.find(k);
      data.emplace(k, MapEntry{src->second.first, it});
    }
    return *this;
  }
  RubyHash(RubyHash&&) = default;
  RubyHash& operator=(RubyHash&&) = default;

  int64_t len() const { return (int64_t)order.size(); }
  int64_t size() const { return len(); }
  int64_t length() const { return len(); }
  bool empty_q() const { return order.empty(); }

  // h[k] returns V&, inserting default-V if absent (Ruby `h[:missing]` is
  // nil; we return a default-constructed V which is nil-ish for variants).
  V& operator[](const K& k) {
    auto it = data.find(k);
    if (it != data.end()) return it->second.first;
    order.push_back(k);
    auto list_it = std::prev(order.end());
    auto [new_it, _] = data.emplace(k, MapEntry{V{}, list_it});
    return new_it->second.first;
  }

  // .store(k, v) — explicit insert / overwrite. Always updates value;
  // preserves insertion position on re-insert.
  V& store(const K& k, const V& v) {
    auto it = data.find(k);
    if (it != data.end()) {
      it->second.first = v;
      return it->second.first;
    }
    order.push_back(k);
    auto list_it = std::prev(order.end());
    auto [new_it, _] = data.emplace(k, MapEntry{v, list_it});
    return new_it->second.first;
  }

  bool include_q(const K& k) const { return data.count(k) > 0; }
  bool has_key_q(const K& k) const { return include_q(k); }

  void delete_(const K& k) {
    auto it = data.find(k);
    if (it == data.end()) return;
    order.erase(it->second.second);  // O(1) via stored iterator
    data.erase(it);
  }

  // Iteration walks the order list — insertion-ordered.
  auto begin() const { return order.begin(); }
  auto end() const { return order.end(); }
};

// Forward declaration: ruby_to_s is used inside RubyArray::join.
template<typename T> static inline RubyString ruby_to_s(T v);

// Generic native array — TI-specialised per element type.
// shared_ptr<vector<T>> backing: copy is cheap (alias), growable via <<.
template<typename T> class RubyArray {
public:
  std::shared_ptr<std::vector<T>> data;
  RubyArray() : data(std::make_shared<std::vector<T>>()) {}
  RubyArray(int64_t size) : data(std::make_shared<std::vector<T>>(size)) {}
  RubyArray(int64_t size, T fill) : data(std::make_shared<std::vector<T>>(size, fill)) {}
  int64_t len() const { return data ? (int64_t)data->size() : 0; }
  T& operator[](int64_t i) {
    if (i < 0) i += (int64_t)data->size();  // Ruby-style negative indexing
    return (*data)[i];
  }
  const T& operator[](int64_t i) const {
    if (i < 0) i += (int64_t)data->size();
    return (*data)[i];
  }
  RubyArray& operator<<(const T& v) { data->push_back(v); return *this; }
  // .delete_at(i) — remove and return element at index (Ruby-style).
  T delete_at(int64_t i) {
    if (i < 0) i += (int64_t)data->size();
    if (i < 0 || i >= (int64_t)data->size()) return T{};
    T v = (*data)[i];
    data->erase(data->begin() + i);
    return v;
  }
  // .insert(i, v) — insert v at index i, shifting right.
  RubyArray& insert(int64_t i, const T& v) {
    if (i < 0) i += (int64_t)data->size() + 1;
    if (i < 0) i = 0;
    if (i > (int64_t)data->size()) i = (int64_t)data->size();
    data->insert(data->begin() + i, v);
    return *this;
  }
  // .slice_assign(lo, hi_incl, other) — replace elements [lo..hi_incl] with other's elements.
  void slice_assign(int64_t lo, int64_t hi_incl, const RubyArray& other) {
    if (lo < 0) lo += (int64_t)data->size();
    if (hi_incl < 0) hi_incl += (int64_t)data->size();
    if (lo < 0) lo = 0;
    if (hi_incl >= (int64_t)data->size()) hi_incl = (int64_t)data->size() - 1;
    data->erase(data->begin() + lo, data->begin() + hi_incl + 1);
    data->insert(data->begin() + lo, other.data->begin(), other.data->end());
  }
  // .dup — deep copy of the backing vector (breaks shared_ptr aliasing).
  RubyArray dup_() const {
    RubyArray out;
    *out.data = *data;
    return out;
  }
  // .join — concatenate elements (with optional separator) into a RubyString.
  RubyString join(const RubyString& sep = RubyString()) const {
    RubyString out;
    for (size_t i = 0; i < data->size(); i++) {
      if (i > 0) out << sep;
      out << ruby_to_s((*data)[i]);
    }
    return out;
  }
};

using RubyArray_I64 = RubyArray<int64_t>;
using RubyArray_F64 = RubyArray<double>;
// Helper: deduce array element type from fill value
template<typename T> RubyArray<T> make_ra(int64_t n, T fill) { return RubyArray<T>(n, fill); }
// (lo..hi).to_a / (lo...hi).to_a — int64_t range enumeration.
static inline RubyArray<int64_t> ruby_range_to_a(int64_t lo, int64_t hi, bool exclusive) {
  int64_t end_inclusive = exclusive ? hi - 1 : hi;
  int64_t n = end_inclusive < lo ? 0 : (end_inclusive - lo + 1);
  RubyArray<int64_t> a(n);
  for (int64_t i = 0; i < n; i++) (*a.data)[i] = lo + i;
  return a;
}

struct RubyNil;

// RubyTree — value-semantic shared-ownership binary tree node.
// Node holds two child shared_ptrs; default-constructed tree is nil.
struct RubyTreeNode;
class RubyTree {
public:
  std::shared_ptr<RubyTreeNode> node;
  RubyTree() = default;
  RubyTree(RubyTree l, RubyTree r);
  RubyTree(const RubyNil&) {}
  bool nil_q() const { return !node; }
  RubyTree operator[](int64_t i) const;
  int64_t len() const { return node ? 2 : 0; }
};
struct RubyTreeNode { std::shared_ptr<RubyTreeNode> left, right; };
inline RubyTree::RubyTree(RubyTree l, RubyTree r) {
  node = std::make_shared<RubyTreeNode>();
  node->left = l.node;
  node->right = r.node;
}
inline RubyTree RubyTree::operator[](int64_t i) const {
  RubyTree t; t.node = (i == 0 ? node->left : node->right); return t;
}

struct RubyNil {
  operator int64_t() const { return 0; }
  operator double() const { return 0.0; }
  operator bool() const { return false; }
  operator RubyString() const { return RubyString(); }
  template<typename T> operator std::shared_ptr<T>() const { return nullptr; }
  template<typename T> operator T() const { return T(); }
};
static const RubyNil RUBY_NIL;

// Wrap a value into std::optional<T> for assignment to optional-typed locals.
// Direct `opt = RubyNil()` is wrong because operator=(U&&) prefers the
// RubyNil → int64_t conversion over RubyNil → optional<int64_t>. This helper
// dispatches on the source type so RubyNil → nullopt, optional<T> stays as-is,
// and other values get wrapped.
template<typename T, typename U>
inline std::optional<T> ruby_to_opt(U&& v) {
  if constexpr (std::is_same_v<std::decay_t<U>, RubyNil>) {
    return std::nullopt;
  } else if constexpr (std::is_same_v<std::decay_t<U>, std::optional<T>>) {
    return std::forward<U>(v);
  } else {
    return std::optional<T>(std::forward<U>(v));
  }
}

static inline bool ruby_nil_q(const RubyTree& t) { return t.nil_q(); }
template<typename T> static inline bool ruby_nil_q(const std::shared_ptr<T>& p) { return !p; }
template<typename T> static inline bool ruby_nil_q(const std::optional<T>& o) { return !o.has_value(); }
template<typename T> static inline bool ruby_nil_q(const T&) { return false; }

// Object.new — empty class with universal "GenericObject" class name.
struct Ruby_Object {};

// .class method — template dispatches on runtime type.
template<typename T> static inline const char* ruby_class_name() { return "Object"; }
template<> inline const char* ruby_class_name<int64_t>() { return "Integer"; }
template<> inline const char* ruby_class_name<double>() { return "Float"; }
template<> inline const char* ruby_class_name<bool>() { return "TrueClass"; }
template<> inline const char* ruby_class_name<RubyString>() { return "String"; }
template<> inline const char* ruby_class_name<Ruby_Object>() { return "Object"; }
template<typename T> static inline const char* ruby_class(const T&) { return ruby_class_name<T>(); }

// to_s — converts primitives to RubyString. Class-specific overrides on user classes.
template<typename T> static inline RubyString ruby_to_s(T v) {
  if constexpr (std::is_same_v<T, RubyString>) return v;
  else if constexpr (std::is_floating_point_v<T>) {
    char buf[64]; auto r = std::to_chars(buf, buf + sizeof(buf) - 4, (double)v);
    *r.ptr = 0;
    bool has_dot = false; for (char* p = buf; p < r.ptr; ++p) if (*p == '.' || *p == 'e' || *p == 'n' || *p == 'i') { has_dot = true; break; }
    if (!has_dot) { *r.ptr++ = '.'; *r.ptr++ = '0'; *r.ptr = 0; }
    return RubyString(buf);
  } else if constexpr (std::is_integral_v<T>) {
    char buf[32]; snprintf(buf, sizeof(buf), "%lld", (long long)v); return RubyString(buf);
  } else return RubyString("#<Object>");
}

// Ruby_Random — MT19937-based (matches Ruby's Random#rand semantics).
class Ruby_Random {
public:
  uint32_t mt[624];
  int index = 624;
  Ruby_Random() = default;
  Ruby_Random(int64_t seed) { reseed((uint32_t)seed); }
  void reseed(uint32_t seed) {
    mt[0] = seed;
    for (int i = 1; i < 624; i++) mt[i] = 1812433253U * (mt[i-1] ^ (mt[i-1] >> 30)) + (uint32_t)i;
    index = 624;
  }
  uint32_t next_u32() {
    if (index >= 624) { generate(); index = 0; }
    uint32_t y = mt[index++];
    y ^= (y >> 11); y ^= (y << 7) & 0x9D2C5680U;
    y ^= (y << 15) & 0xEFC60000U; y ^= (y >> 18);
    return y;
  }
  void generate() {
    for (int i = 0; i < 624; i++) {
      uint32_t y = (mt[i] & 0x80000000U) | (mt[(i+1) % 624] & 0x7fffffffU);
      mt[i] = mt[(i+397) % 624] ^ (y >> 1);
      if (y & 1) mt[i] ^= 0x9908B0DFU;
    }
  }
  double rand() {
    uint32_t a = next_u32() >> 5, b = next_u32() >> 6;
    return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);
  }
  int64_t rand(int64_t n) { return (int64_t)(rand() * n); }
  bool nil_q() const { return false; }
};
template<> inline const char* ruby_class_name<Ruby_Random>() { return "Random"; }

// Ruby-flavored puts: chooses format based on type
template<typename T> static inline void ruby_puts(T v) {
  if constexpr (std::is_same_v<T, bool>) {
    printf(v ? "true\n" : "false\n");
  } else if constexpr (std::is_floating_point_v<T>) {
    // Shortest round-trippable representation (matches Ruby's Float#to_s closely)
    char buf[64]; auto r = std::to_chars(buf, buf + sizeof(buf) - 4, (double)v);
    *r.ptr = 0;
    // Ensure trailing .0 for integer-valued doubles (Ruby convention)
    bool has_dot = false; for (char* p = buf; p < r.ptr; ++p) if (*p == '.' || *p == 'e' || *p == 'n' || *p == 'i') { has_dot = true; break; }
    if (!has_dot) { *r.ptr++ = '.'; *r.ptr++ = '0'; *r.ptr = 0; }
    printf("%s\n", buf);
  } else if constexpr (std::is_integral_v<T>) {
    printf("%lld\n", (long long)v);
  } else if constexpr (std::is_same_v<T, RubyString>) {
    fwrite(v.bytes.data(), 1, v.bytes.size(), stdout);
    fputc('\n', stdout);
  } else if constexpr (requires { v.len(); v[0]; }) {
    // RubyArray: Ruby's puts prints each element on its own line
    // (recursive flatten). Empty array → empty line.
    if (v.len() == 0) { printf("\n"); }
    else for (int64_t i = 0; i < v.len(); i++) ruby_puts(v[i]);
  } else {
    printf("#<Object>\n");
  }
}
static inline void ruby_puts(const char* s) { printf("%s\n", s); }

// Optional: print value if has_value, else empty line (Ruby's `puts nil`).
// Lets TI-inferred `std::optional<T>` locals print correctly.
template<typename T>
static inline void ruby_puts(const std::optional<T>& v) {
  if (v.has_value()) ruby_puts(*v);
  else printf("\n");
}

#endif  // FROZONE_RUNTIME_HPP
