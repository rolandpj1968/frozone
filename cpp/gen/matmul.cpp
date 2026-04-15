#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>

// --- Frozone C++ runtime (minimal) ---

#include <memory>

// Mutable byte-oriented string. Encoding is tracked nominally
// but all methods operate on bytes (matches Ruby binary semantics).
#include <vector>
#include <cstring>
class RubyString {
public:
  std::vector<uint8_t> bytes;
  int64_t len = 0;
  RubyString() = default;
  RubyString(const char* s) { if (s) { size_t n = strlen(s); bytes.assign(s, s + n); len = n; } }
  RubyString(const char* s, size_t n) { bytes.assign(s, s + n); len = n; }
  int64_t bytesize() const { return len; }
  int64_t size() const { return len; }
  int64_t length() const { return len; }
  int64_t get_byte(int64_t i) const { return (i >= 0 && i < len) ? (int64_t)bytes[i] : 0; }
  void set_byte(int64_t i, int64_t v) { if (i >= 0 && i < len) bytes[i] = (uint8_t)(v & 0xff); }
  RubyString dup_() const { return *this; }
  RubyString& operator<<(const RubyString& o) {
    bytes.insert(bytes.end(), o.bytes.begin(), o.bytes.end()); len = (int64_t)bytes.size(); return *this;
  }
  RubyString& operator<<(const char* s) {
    if (s) { size_t n = strlen(s); bytes.insert(bytes.end(), s, s + n); len = (int64_t)bytes.size(); } return *this;
  }
  bool operator==(const RubyString& o) const { return bytes == o.bytes; }
  bool operator!=(const RubyString& o) const { return bytes != o.bytes; }
};
using Ruby_String = RubyString;

// Generic native array — TI-specialised per element type
// Uses shared_ptr so nested arrays / temporaries copy cheaply
#include <memory>
template<typename T> class RubyArray {
public:
  std::shared_ptr<T[]> data;
  int64_t len;
  RubyArray() : data(nullptr), len(0) {}
  RubyArray(int64_t size) : data(new T[size > 0 ? size : 1]()), len(size) {}
  RubyArray(int64_t size, T fill) : data(new T[size > 0 ? size : 1]), len(size) {
    for (int64_t i = 0; i < size; i++) data[i] = fill;
  }
  T& operator[](int64_t i) { return data[i]; }
  const T& operator[](int64_t i) const { return data[i]; }
};

using RubyArray_I64 = RubyArray<int64_t>;
using RubyArray_F64 = RubyArray<double>;
// Helper: deduce array element type from fill value
template<typename T> RubyArray<T> make_ra(int64_t n, T fill) { return RubyArray<T>(n, fill); }

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
};
static const RubyNil RUBY_NIL;

// Uniform nil check — dispatches on type.
static inline bool ruby_nil_q(const RubyTree& t) { return t.nil_q(); }
template<typename T> static inline bool ruby_nil_q(const std::shared_ptr<T>& p) { return !p; }
template<typename T> static inline bool ruby_nil_q(const T&) { return false; }

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
  } else {
    printf("#<Object>\n");
  }
}
static inline void ruby_puts(const char* s) { printf("%s\n", s); }



static const int64_t N = 200LL;

static auto make_shareable(auto x) {
  return x;
}

static auto matgen(auto n) {
  auto tmp = ((1.0 / n) / n);
  return ({ auto _n = n; int64_t i = 0; auto _e0 = ({ auto _n = n; int64_t j = 0; auto _e0 = ((tmp * (i - j)) * (i + j)); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (j = 1; j < _n; j++) { _arr[j] = ((tmp * (i - j)) * (i + j)); } _arr; }); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (i = 1; i < _n; i++) { _arr[i] = ({ auto _n = n; int64_t j = 0; auto _e0 = ((tmp * (i - j)) * (i + j)); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (j = 1; j < _n; j++) { _arr[j] = ((tmp * (i - j)) * (i + j)); } _arr; }); } _arr; });
}

static auto matmul(auto a, auto b) {
  auto m = a.len;
  auto n = a[INT64_C(0)].len;
  auto p = b[INT64_C(0)].len;
  auto c = ({ auto _n = m; int64_t _ai = 0; auto _e0 = make_ra(p, 0.0); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (_ai = 1; _ai < _n; _ai++) { _arr[_ai] = make_ra(p, 0.0); } _arr; });
  for (int64_t i = INT64_C(0); i < m; i++) {
    auto ci = c[i];
    auto ai = a[i];
    int64_t k = INT64_C(0);
    while ((k < n)) {
    auto aik = ai[k];
    auto bk = b[k];
    int64_t j = INT64_C(0);
    while ((j < p)) {
    ci[j] += (aik * bk[j]);
    j = (j + INT64_C(1));
  };
    k = (k + INT64_C(1));
  };
  }
  return c;
}


int main() {
  double last = 0.0;
  for (int64_t _i = 0; _i < INT64_C(20); _i++) {
    auto a = matgen(N);
    auto b = matgen(N);
    auto c = matmul(a, b);
    last = c[(N / INT64_C(2))][(N / INT64_C(2))];
  }
  ruby_puts(last);
  return 0;
}
