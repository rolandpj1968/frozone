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
  } else {
    printf("#<Object>\n");
  }
}
static inline void ruby_puts(const char* s) { printf("%s\n", s); }




static auto make_shareable(auto x) {
  return x;
}

static auto sd_genmat() {
  int64_t r = 0;
  int64_t i = 0;
  int64_t j = 0;
  int64_t k = 0;
  int64_t r2 = 0;
  int64_t c2 = 0;
  auto mr = ({ auto _n = INT64_C(324); int64_t _ai = 0; auto _e0 = RubyArray_I64(0); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (_ai = 1; _ai < _n; _ai++) { _arr[_ai] = RubyArray_I64(0); } _arr; });
  auto mc = ({ auto _n = INT64_C(729); int64_t _ai = 0; auto _e0 = make_ra(INT64_C(4), INT64_C(0)); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (_ai = 1; _ai < _n; _ai++) { _arr[_ai] = make_ra(INT64_C(4), INT64_C(0)); } _arr; });
  r = INT64_C(0);
  i = INT64_C(0);
  while ((i < INT64_C(9))) {
    j = INT64_C(0);
    while ((j < INT64_C(9))) {
    k = INT64_C(0);
    while ((k < INT64_C(9))) {
    auto& mcr = mc[r];
    mcr[INT64_C(0)] = ((INT64_C(9) * i) + j);
    mcr[INT64_C(1)] = ((((((i / INT64_C(3)) * INT64_C(3)) + (j / INT64_C(3))) * INT64_C(9)) + k) + INT64_C(81));
    mcr[INT64_C(2)] = (((INT64_C(9) * i) + k) + INT64_C(162));
    mcr[INT64_C(3)] = (((INT64_C(9) * j) + k) + INT64_C(243));
    r = (r + INT64_C(1));
    k = (k + INT64_C(1));
  };
    j = (j + INT64_C(1));
  };
    i = (i + INT64_C(1));
  }
  r2 = INT64_C(0);
  while ((r2 < INT64_C(729))) {
    c2 = INT64_C(0);
    while ((c2 < INT64_C(4))) {
    (mr[mc[r2][c2]] << r2);
    c2 = (c2 + INT64_C(1));
  };
    r2 = (r2 + INT64_C(1));
  }
  return ({ auto _e0 = mr; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mc; _a; });
}

static auto sd_update_forward(auto mr, auto mc, auto sr, auto sc, auto r) {
  int64_t min = 0;
  int64_t min_c = 0;
  std::decay_t<decltype(mc[r])> mcr{};
  int64_t c2 = 0;
  int64_t r2 = 0;
  int64_t cc2 = 0;
  min = INT64_C(10);
  min_c = INT64_C(0);
  mcr = mc[r];
  c2 = INT64_C(0);
  while ((c2 < INT64_C(4))) {
    sc[mcr[c2]] += INT64_C(128);
    c2 = (c2 + INT64_C(1));
  }
  c2 = INT64_C(0);
  while ((c2 < INT64_C(4))) {
    auto& mrc = mr[mcr[c2]];
    r2 = INT64_C(0);
    while ((r2 < INT64_C(9))) {
    auto& rr = mrc[r2];
    if ((sr[rr] += INT64_C(1) == INT64_C(1))) {
    auto& p = mc[rr]; cc2 = INT64_C(0); while ((cc2 < INT64_C(4))) {
      auto& cc = p[cc2];
      if ((sc[cc] -= INT64_C(1) < min)) {
      min = sc[cc]; min_c = cc;
    };
      cc2 = (cc2 + INT64_C(1));
    };
  };
    r2 = (r2 + INT64_C(1));
  };
    c2 = (c2 + INT64_C(1));
  }
  return ({ auto _e0 = min; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = min_c; _a; });
}

static auto sd_update_reverse(auto mr, auto mc, auto sr, auto sc, auto r) {
  int64_t c2 = 0;
  int64_t r2 = 0;
  c2 = INT64_C(0);
  while ((c2 < INT64_C(4))) {
    sc[mc[r][c2]] -= INT64_C(128);
    c2 = (c2 + INT64_C(1));
  }
  c2 = INT64_C(0);
  while ((c2 < INT64_C(4))) {
    auto& c = mc[r][c2];
    r2 = INT64_C(0);
    while ((r2 < INT64_C(9))) {
    auto& rr = mr[c][r2];
    if ((sr[rr] -= INT64_C(1) == INT64_C(0))) {
    auto& p = mc[rr]; sc[p[INT64_C(0)]] += INT64_C(1); sc[p[INT64_C(1)]] += INT64_C(1); sc[p[INT64_C(2)]] += INT64_C(1); sc[p[INT64_C(3)]] += INT64_C(1);
  };
    r2 = (r2 + INT64_C(1));
  };
    c2 = (c2 + INT64_C(1));
  }
  return INT64_C(0);
}

static auto sd_solve(auto mr, auto mc, auto s) {
  std::decay_t<decltype(make_ra(INT64_C(729), INT64_C(0)))> sr{};
  std::decay_t<decltype(make_ra(INT64_C(324), INT64_C(9)))> sc{};
  int64_t hints = 0;
  int64_t i = 0;
  int64_t a = 0;
  std::decay_t<decltype(make_ra(INT64_C(81), INT64_C(-1)))> cr{};
  std::decay_t<decltype(make_ra(INT64_C(81), INT64_C(0)))> cc{};
  int64_t min = 0;
  int64_t dir = 0;
  int64_t c = 0;
  std::decay_t<decltype(make_ra(INT64_C(81), INT64_C(0)))> o{};
  int64_t j = 0;
  sr = make_ra(INT64_C(729), INT64_C(0));
  sc = make_ra(INT64_C(324), INT64_C(9));
  hints = INT64_C(0);
  i = INT64_C(0);
  while ((i < INT64_C(81))) {
    auto& rb_char = s[i];
    a = if (({ auto _l = ((rb_char >= RubyString("1", 1))); auto _r = ((rb_char <= RubyString("9", 1))); (_l) ? _r : decltype(_r)(_l); })) {
    (rb_char.ord() - INT64_C(49));
  } else {
    INT64_C(-1);
  };
    if ((a >= INT64_C(0))) {
    sd_update_forward(mr, mc, sr, sc, ((i * INT64_C(9)) + a)); hints = (hints + INT64_C(1));
  };
    i = (i + INT64_C(1));
  }
  cr = make_ra(INT64_C(81), INT64_C(-1));
  cc = make_ra(INT64_C(81), INT64_C(0));
  i = INT64_C(0);
  min = INT64_C(10);
  dir = INT64_C(1);
  while (true) {
    while (({ auto _l = ((i >= INT64_C(0))); auto _r = ((i < (INT64_C(81) - hints))); (_l) ? _r : decltype(_r)(_l); })) {
    if ((dir == INT64_C(1))) {
    if ((min > INT64_C(1))) {
      c = INT64_C(0); while ((c < INT64_C(324))) {
        if ((sc[c] < min)) {
        min = sc[c]; cc[i] = c; if ((min < INT64_C(2))) {
          break;
        };
      };
        c = (c + INT64_C(1));
      };
    }; if (({ auto _l = ((min == INT64_C(0))); auto _r = ((min == INT64_C(10))); (_l) ? decltype(_r)(_l) : _r; })) {
      cr[i] = dir = INT64_C(-1); i = (i - INT64_C(1));
    };
  };
    c = cc[i];
    if (({ auto _l = ((dir == INT64_C(-1))); auto _r = ((cr[i] >= INT64_C(0))); (_l) ? _r : decltype(_r)(_l); })) {
    sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]]);
  };
    auto r2 = (cr[i] + INT64_C(1));
    while (({ auto _l = ((r2 < INT64_C(9))); auto _r = ((sr[mr[c][r2]] != INT64_C(0))); (_l) ? _r : decltype(_r)(_l); })) {
    r2 = (r2 + INT64_C(1));
  };
    if ((r2 < INT64_C(9))) {
    /* UNSUPPORTED masgn */; cr[i] = r2; dir = INT64_C(1); i = (i + INT64_C(1));
  } else {
    cr[i] = INT64_C(-1); dir = INT64_C(-1); i = (i - INT64_C(1));
  };
  };
    if ((i < INT64_C(0))) {
    break;
  };
    o = make_ra(INT64_C(81), INT64_C(0));
    j = INT64_C(0);
    while ((j < INT64_C(81))) {
    o[j] = (s[j].ord() - INT64_C(48));
    j = (j + INT64_C(1));
  };
    j = INT64_C(0);
    while ((j < i)) {
    auto& r = mr[cc[j]][cr[j]];
    o[(r / INT64_C(9))] = ((r % INT64_C(9)) + INT64_C(1));
    j = (j + INT64_C(1));
  };
    o.join();
    i = (i - INT64_C(1));
    dir = INT64_C(-1);
  }
  return INT64_C(0);
}


int main() {
  /* UNSUPPORTED masgn */;
  RubyString last = RubyString("", 0);
  for (int64_t _i = 0; _i < INT64_C(20); _i++) {
    HARD20.each();
  }
  ruby_puts(last);
  return 0;
}
