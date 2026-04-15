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
  RubyString& operator<<(const RubyString& o) {
    bytes.insert(bytes.end(), o.bytes.begin(), o.bytes.end()); return *this;
  }
  RubyString& operator<<(const char* s) {
    if (s) { size_t n = strlen(s); bytes.insert(bytes.end(), s, s + n); } return *this;
  }
  bool operator==(const RubyString& o) const { return bytes == o.bytes; }
  bool operator!=(const RubyString& o) const { return bytes != o.bytes; }
};
using Ruby_String = RubyString;

// Generic native array — TI-specialised per element type.
// shared_ptr<vector<T>> backing: copy is cheap (alias), growable via <<.
template<typename T> class RubyArray {
public:
  std::shared_ptr<std::vector<T>> data;
  RubyArray() : data(std::make_shared<std::vector<T>>()) {}
  RubyArray(int64_t size) : data(std::make_shared<std::vector<T>>(size)) {}
  RubyArray(int64_t size, T fill) : data(std::make_shared<std::vector<T>>(size, fill)) {}
  int64_t len() const { return data ? (int64_t)data->size() : 0; }
  T& operator[](int64_t i) { return (*data)[i]; }
  const T& operator[](int64_t i) const { return (*data)[i]; }
  RubyArray& operator<<(const T& v) { data->push_back(v); return *this; }
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



static const int64_t N = 9LL;

static auto fannkuch(auto n) {
  auto p = (n + 1LL).to_a();
  auto s = p;
  auto q = p;
  int64_t sign = INT64_C(1);
  int64_t sum = int64_t maxflips = INT64_C(0);
  while (true) {
    if ((auto q1 = p[INT64_C(1)] != INT64_C(1))) {
    q[(INT64_C(-1) + 1LL)] = p; int64_t flips = INT64_C(1); while (!((auto qq = q[q1] == INT64_C(1)))) {
      q[q1] = q1;
      if ((q1 >= INT64_C(4))) {
      i = INT64_C(2); j = (q1 - INT64_C(1)); while ((i < j)) {
        local(q, 0) = q[j]; local(q, 0) = q[i];
        auto i = (i + INT64_C(1));
        auto j = (j - INT64_C(1));
      };
    };
      q1 = qq;
      flips = (flips + INT64_C(1));
    }; sum = (sum + (sign * flips)); if ((flips > maxflips)) {
      maxflips = flips;
    };
  };
    if ((sign == INT64_C(1))) {
    local(p, 0) = p[INT64_C(2)]; local(p, 0) = p[INT64_C(1)]; sign = INT64_C(-1);
  } else {
    local(p, 0) = p[INT64_C(3)]; local(p, 0) = p[INT64_C(2)]; sign = INT64_C(1); i = INT64_C(3); while (((i <= n) && (s[i] == INT64_C(1)))) {
      if ((i == n)) {
      return ({ auto _e0 = sum; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = maxflips; _a; });
    };
      s[i] = i;
      auto t = p.delete_at(INT64_C(1));
      i = (i + INT64_C(1));
      p.insert(i, t);
    }; if ((i <= n)) {
      s[i] -= INT64_C(1);
    };
  };
  }
  return INT64_C(0);
}


int main() {
  int64_t last = INT64_C(0);
  for (int64_t _i = 0; _i < INT64_C(10); _i++) {
    last = fannkuch(N);
  }
  ruby_puts(last);
  return 0;
}
