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
    // RubyArray: Ruby's puts prints each element on its own line
    // (recursive flatten). Empty array → empty line.
    if (v.len() == 0) { printf("\n"); }
    else for (int64_t i = 0; i < v.len(); i++) ruby_puts(v[i]);
  } else {
    printf("#<Object>\n");
  }
}
static inline void ruby_puts(const char* s) { printf("%s\n", s); }



static auto HARD20 = []() { RubyArray<RubyString> _a(20);
  (*_a.data)[0] = RubyString("..............3.85..1.2.......5.7.....4...1...9.......5......73..2.1........4...9", 81);
  (*_a.data)[1] = RubyString(".......12........3..23..4....18....5.6..7.8.......9.....85.....9...4.5..47...6...", 81);
  (*_a.data)[2] = RubyString(".2..5.7..4..1....68....3...2....8..3.4..2.5.....6...1...2.9.....9......57.4...9..", 81);
  (*_a.data)[3] = RubyString("........3..1..56...9..4..7......9.5.7.......8.5.4.2....8..2..9...35..1..6........", 81);
  (*_a.data)[4] = RubyString("12.3....435....1....4........54..2..6...7.........8.9...31..5.......9.7.....6...8", 81);
  (*_a.data)[5] = RubyString("1.......2.9.4...5...6...7...5.9.3.......7.......85..4.7.....6...3...9.8...2.....1", 81);
  (*_a.data)[6] = RubyString(".......39.....1..5..3.5.8....8.9...6.7...2...1..4.......9.8..5..2....6..4..7.....", 81);
  (*_a.data)[7] = RubyString("12.3.....4.....3....3.5......42..5......8...9.6...5.7...15..2......9..6......7..8", 81);
  (*_a.data)[8] = RubyString("..3..6.8....1..2......7...4..9..8.6..3..4...1.7.2.....3....5.....5...6..98.....5.", 81);
  (*_a.data)[9] = RubyString("1.......9..67...2..8....4......75.3...5..2....6.3......9....8..6...4...1..25...6.", 81);
  (*_a.data)[10] = RubyString("..9...4...7.3...2.8...6...71..8....6....1..7.....56...3....5..1.4.....9...2...7..", 81);
  (*_a.data)[11] = RubyString("....9..5..1.....3...23..7....45...7.8.....2.......64...9..1.....8..6......54....7", 81);
  (*_a.data)[12] = RubyString("4...3.......6..8..........1....5..9..8....6...7.2........1.27..5.3....4.9........", 81);
  (*_a.data)[13] = RubyString("7.8...3.....2.1...5.........4.....263...8.......1...9..9.6....4....7.5...........", 81);
  (*_a.data)[14] = RubyString("3.7.4...........918........4.....7.....16.......25..........38..9....5...2.6.....", 81);
  (*_a.data)[15] = RubyString("........8..3...4...9..2..6.....79.......612...6.5.2.7...8...5...1.....2.4.5.....3", 81);
  (*_a.data)[16] = RubyString(".......1.4.........2...........5.4.7..8...3....1.9....3..4..2...5.1........8.6...", 81);
  (*_a.data)[17] = RubyString(".......12....35......6...7.7.....3.....4..8..1...........12.....8.....4..5....6..", 81);
  (*_a.data)[18] = RubyString("1.......2.9.4...5...6...7...5.3.4.......6........58.4...2...6...3...9.8.7.......1", 81);
  (*_a.data)[19] = RubyString(".....1.2.3...4.5.....6....7..2.....1.8..9..3.4.....8..5....2....9..3.4....67.....", 81);
  return _a; }();

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
  (r = INT64_C(0));
  (i = INT64_C(0));
  while ((i < INT64_C(9))) {
    (j = INT64_C(0));
    while ((j < INT64_C(9))) {
    (k = INT64_C(0));
    while ((k < INT64_C(9))) {
    auto mcr = mc[r];
    mcr[INT64_C(0)] = ((INT64_C(9) * i) + j);
    mcr[INT64_C(1)] = ((((((i / INT64_C(3)) * INT64_C(3)) + (j / INT64_C(3))) * INT64_C(9)) + k) + INT64_C(81));
    mcr[INT64_C(2)] = (((INT64_C(9) * i) + k) + INT64_C(162));
    mcr[INT64_C(3)] = (((INT64_C(9) * j) + k) + INT64_C(243));
    (r = (r + INT64_C(1)));
    (k = (k + INT64_C(1)));
  };
    (j = (j + INT64_C(1)));
  };
    (i = (i + INT64_C(1)));
  }
  (r2 = INT64_C(0));
  while ((r2 < INT64_C(729))) {
    (c2 = INT64_C(0));
    while ((c2 < INT64_C(4))) {
    (mr[mc[r2][c2]] << r2);
    (c2 = (c2 + INT64_C(1)));
  };
    (r2 = (r2 + INT64_C(1)));
  }
  return ({ auto _e0 = mr; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mc; _a; });
}

static auto sd_update_forward(auto mr, auto mc, auto sr, auto sc, auto r) {
  int64_t min = 0;
  int64_t min_c = 0;
  std::decay_t<decltype(mc[r])> mcr{};
  int64_t c2 = 0;
  std::decay_t<decltype(mr[mcr[c2]])> mrc{};
  int64_t r2 = 0;
  std::decay_t<decltype(mrc[r2])> rr{};
  std::decay_t<decltype(mc[rr])> p{};
  int64_t cc2 = 0;
  std::decay_t<decltype(p[cc2])> cc{};
  (min = INT64_C(10));
  (min_c = INT64_C(0));
  (mcr = mc[r]);
  (c2 = INT64_C(0));
  while ((c2 < INT64_C(4))) {
    sc[mcr[c2]] += INT64_C(128);
    (c2 = (c2 + INT64_C(1)));
  }
  (c2 = INT64_C(0));
  while ((c2 < INT64_C(4))) {
    (mrc = mr[mcr[c2]]);
    (r2 = INT64_C(0));
    while ((r2 < INT64_C(9))) {
    (rr = mrc[r2]);
    if ((sr[rr] += INT64_C(1) == INT64_C(1))) {
    (p = mc[rr]);
    (cc2 = INT64_C(0));
    while ((cc2 < INT64_C(4))) {
    (cc = p[cc2]);
    if ((sc[cc] -= INT64_C(1) < min)) {
    (min = sc[cc]);
    (min_c = cc);
  };
    (cc2 = (cc2 + INT64_C(1)));
  };
  };
    (r2 = (r2 + INT64_C(1)));
  };
    (c2 = (c2 + INT64_C(1)));
  }
  return ({ auto _e0 = min; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = min_c; _a; });
}

static auto sd_update_reverse(auto mr, auto mc, auto sr, auto sc, auto r) {
  int64_t c2 = 0;
  std::decay_t<decltype(mc[r][c2])> c{};
  int64_t r2 = 0;
  std::decay_t<decltype(mr[c][r2])> rr{};
  std::decay_t<decltype(mc[rr])> p{};
  (c2 = INT64_C(0));
  while ((c2 < INT64_C(4))) {
    sc[mc[r][c2]] -= INT64_C(128);
    (c2 = (c2 + INT64_C(1)));
  }
  (c2 = INT64_C(0));
  while ((c2 < INT64_C(4))) {
    (c = mc[r][c2]);
    (r2 = INT64_C(0));
    while ((r2 < INT64_C(9))) {
    (rr = mr[c][r2]);
    if ((sr[rr] -= INT64_C(1) == INT64_C(0))) {
    (p = mc[rr]);
    sc[p[INT64_C(0)]] += INT64_C(1);
    sc[p[INT64_C(1)]] += INT64_C(1);
    sc[p[INT64_C(2)]] += INT64_C(1);
    sc[p[INT64_C(3)]] += INT64_C(1);
  };
    (r2 = (r2 + INT64_C(1)));
  };
    (c2 = (c2 + INT64_C(1)));
  }
  return RUBY_NIL;
}

static auto sd_solve(auto mr, auto mc, auto s) {
  std::decay_t<decltype(make_ra(INT64_C(729), INT64_C(0)))> sr{};
  std::decay_t<decltype(make_ra(INT64_C(324), INT64_C(9)))> sc{};
  int64_t hints = 0;
  int64_t i = 0;
  std::decay_t<decltype(s[i])> rb_char{};
  int64_t a = 0;
  std::decay_t<decltype(make_ra(INT64_C(81), INT64_C(-1)))> cr{};
  std::decay_t<decltype(make_ra(INT64_C(81), INT64_C(0)))> cc{};
  int64_t min = 0;
  int64_t dir = 0;
  int64_t c = 0;
  std::decay_t<decltype((cr[i] + INT64_C(1)))> r2{};
  std::decay_t<decltype(make_ra(INT64_C(81), INT64_C(0)))> o{};
  int64_t j = 0;
  std::decay_t<decltype(mr[cc[j]][cr[j]])> r{};
  (sr = make_ra(INT64_C(729), INT64_C(0)));
  (sc = make_ra(INT64_C(324), INT64_C(9)));
  (hints = INT64_C(0));
  (i = INT64_C(0));
  while ((i < INT64_C(81))) {
    auto rb_char = s[i];
    (a = (({ auto _l = ((rb_char >= RubyString("1", 1))); (_l) ? decltype(((rb_char <= RubyString("9", 1))))((rb_char <= RubyString("9", 1))) : decltype(((rb_char <= RubyString("9", 1))))(_l); }) ? ((rb_char.ord() - INT64_C(49))) : (INT64_C(-1))));
    if ((a >= INT64_C(0))) {
    sd_update_forward(mr, mc, sr, sc, ((i * INT64_C(9)) + a));
    (hints = (hints + INT64_C(1)));
  };
    (i = (i + INT64_C(1)));
  }
  (cr = make_ra(INT64_C(81), INT64_C(-1)));
  (cc = make_ra(INT64_C(81), INT64_C(0)));
  (i = INT64_C(0));
  (min = INT64_C(10));
  (dir = INT64_C(1));
  while (true) {
    while (({ auto _l = ((i >= INT64_C(0))); (_l) ? decltype(((i < (INT64_C(81) - hints))))((i < (INT64_C(81) - hints))) : decltype(((i < (INT64_C(81) - hints))))(_l); })) {
    if ((dir == INT64_C(1))) {
    if ((min > INT64_C(1))) {
    (c = INT64_C(0));
    while ((c < INT64_C(324))) {
    if ((sc[c] < min)) {
    (min = sc[c]);
    cc[i] = c;
    if ((min < INT64_C(2))) {
    break;
  };
  };
    (c = (c + INT64_C(1)));
  };
  };
    if (({ auto _l = ((min == INT64_C(0))); (_l) ? decltype(((min == INT64_C(10))))(_l) : ((min == INT64_C(10))); })) {
    cr[i] = (dir = INT64_C(-1));
    (i = (i - INT64_C(1)));
  };
  };
    (c = cc[i]);
    if (({ auto _l = ((dir == INT64_C(-1))); (_l) ? decltype(((cr[i] >= INT64_C(0))))((cr[i] >= INT64_C(0))) : decltype(((cr[i] >= INT64_C(0))))(_l); })) {
    sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]]);
  };
    (r2 = (cr[i] + INT64_C(1)));
    while (({ auto _l = ((r2 < INT64_C(9))); (_l) ? decltype(((sr[mr[c][r2]] != INT64_C(0))))((sr[mr[c][r2]] != INT64_C(0))) : decltype(((sr[mr[c][r2]] != INT64_C(0))))(_l); })) {
    (r2 = (r2 + INT64_C(1)));
  };
    if ((r2 < INT64_C(9))) {
    auto _masgn1 = sd_update_forward(mr, mc, sr, sc, mr[c][r2]);
    min = _masgn1[INT64_C(0)];
    cc[(i + INT64_C(1))] = _masgn1[INT64_C(1)];
    cr[i] = r2;
    (dir = INT64_C(1));
    (i = (i + INT64_C(1)));
  } else {
    cr[i] = INT64_C(-1);
    (dir = INT64_C(-1));
    (i = (i - INT64_C(1)));
  };
  };
    if ((i < INT64_C(0))) {
    break;
  };
    (o = make_ra(INT64_C(81), INT64_C(0)));
    (j = INT64_C(0));
    while ((j < INT64_C(81))) {
    o[j] = (s[j].ord() - INT64_C(48));
    (j = (j + INT64_C(1)));
  };
    (j = INT64_C(0));
    while ((j < i)) {
    (r = mr[cc[j]][cr[j]]);
    o[(r / INT64_C(9))] = ((r % INT64_C(9)) + INT64_C(1));
    (j = (j + INT64_C(1)));
  };
    o.join();
    (i = (i - INT64_C(1)));
    (dir = INT64_C(-1));
  }
  return RUBY_NIL;
}


int main() {
  RubyString last;
  auto _masgn2 = sd_genmat();
  auto mr = _masgn2[INT64_C(0)];
  auto mc = _masgn2[INT64_C(1)];
  (last = RubyString("", 0));
  for (int64_t _i = 0; _i < INT64_C(20); _i++) {
    for (auto& line : *HARD20.data) {
      (last = sd_solve(mr, mc, line));
    };
  }
  ruby_puts(last);
  return 0;
}
