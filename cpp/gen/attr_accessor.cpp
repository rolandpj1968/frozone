#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>

// --- Frozone C++ runtime (minimal) ---

#include <memory>
#include <type_traits>
#include <charconv>
#include <cinttypes>

// Mutable byte-oriented string. Encoding is tracked nominally
// but all methods operate on bytes (matches Ruby binary semantics).
#include <vector>
#include <cstring>
class RubyString {
public:
  std::vector<uint8_t> bytes;
  RubyString() = default;
  RubyString(const char* s) { if (s) { size_t n = strlen(s); bytes.assign(s, s + n); } }
  RubyString(const char* s, size_t n) { bytes.assign(s, s + n); }
  int64_t len() const { return (int64_t)bytes.size(); }
  int64_t bytesize() const { return (int64_t)bytes.size(); }
  int64_t size() const { return (int64_t)bytes.size(); }
  int64_t length() const { return (int64_t)bytes.size(); }
  int64_t get_byte(int64_t i) const { return (i >= 0 && i < (int64_t)bytes.size()) ? (int64_t)bytes[i] : 0; }
  void set_byte(int64_t i, int64_t v) { if (i >= 0 && i < (int64_t)bytes.size()) bytes[i] = (uint8_t)(v & 0xff); }
  RubyString dup_() const { return *this; }
  int64_t ord() const { return bytes.empty() ? 0 : (int64_t)bytes[0]; }
  RubyString operator[](int64_t i) const {
    if (i < 0 || i >= (int64_t)bytes.size()) return RubyString();
    return RubyString((const char*)&bytes[i], 1);
  }
  RubyString& operator<<(const RubyString& o) {
    bytes.insert(bytes.end(), o.bytes.begin(), o.bytes.end()); return *this;
  }
  RubyString& operator<<(const char* s) {
    if (s) { size_t n = strlen(s); bytes.insert(bytes.end(), s, s + n); } return *this;
  }
  bool operator==(const RubyString& o) const { return bytes == o.bytes; }
  bool operator!=(const RubyString& o) const { return bytes != o.bytes; }
  bool operator<(const RubyString& o) const { return bytes < o.bytes; }
  bool operator<=(const RubyString& o) const { return bytes <= o.bytes; }
  bool operator>(const RubyString& o) const { return bytes > o.bytes; }
  bool operator>=(const RubyString& o) const { return bytes >= o.bytes; }
};
using Ruby_String = RubyString;

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

// Uniform nil check — dispatches on type.
static inline bool ruby_nil_q(const RubyTree& t) { return t.nil_q(); }
template<typename T> static inline bool ruby_nil_q(const std::shared_ptr<T>& p) { return !p; }
template<typename T> static inline bool ruby_nil_q(const T&) { return false; }

// Object.new — empty class with universal "GenericObject" class name.
struct Ruby_Object {};

// .class method — template dispatches on runtime type.
template<typename T> static inline const char* ruby_class_name() { return "Object"; }
template<> inline const char* ruby_class_name<int64_t>() { return "Integer"; }
template<> inline const char* ruby_class_name<double>() { return "Float"; }
template<> inline const char* ruby_class_name<bool>() { return "TrueClass"; }
template<> inline const char* ruby_class_name<RubyString>() { return "String"; }
template<> inline const char* ruby_class_name<Ruby_Object>() { return "GenericObject"; }
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
#include <type_traits>
#include <charconv>
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
    // RubyArray: Ruby's puts emits `[e1, e2, ...]` (inspect-style)
    printf("[");
    for (int64_t i = 0; i < v.len(); i++) {
      printf(i == 0 ? "" : ", ");
      auto x = v[i]; printf("%lld", (long long)x);
    }
    printf("]\n");
  } else {
    printf("#<Object>\n");
  }
}
static inline void ruby_puts(const char* s) { printf("%s\n", s); }


struct Ruby_TheClass {
  struct Impl {
    int64_t iv_v0 = 0;
    int64_t iv_v1 = 0;
    int64_t iv_v2 = 0;
    int64_t iv_levar = 0;
  };
  std::shared_ptr<Impl> p;

  Ruby_TheClass() : p(std::make_shared<Impl>()) {
    p->iv_v0 = INT64_C(1);
    p->iv_v1 = INT64_C(2);
    p->iv_v2 = INT64_C(3);
    p->iv_levar = INT64_C(1);
  }
  Ruby_TheClass(const RubyNil&) {}

  auto levar() {
    return p->iv_levar;
  }

  auto set_levar(auto __anon_req__) {
    p->iv_levar = __anon_req__;
    return p->iv_levar;
  }

  auto get_value_loop() {
    int64_t sum = 0;
    int64_t i = 0;
    (sum = INT64_C(0));
    (i = INT64_C(0));
    while ((i < INT64_C(10000))) {
      (sum = (sum + levar()));
      (sum = (sum + levar()));
      (sum = (sum + levar()));
      (sum = (sum + levar()));
      (sum = (sum + levar()));
      (i = (i + INT64_C(1)));
    }
    return sum;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_TheClass>() { return "TheClass"; }


static Ruby_TheClass OBJ;


int main() {
  int64_t last = 0;
  (last = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(300); _i++) {
    (last = OBJ.get_value_loop());
  }
  ruby_puts(last);
  return 0;
}
