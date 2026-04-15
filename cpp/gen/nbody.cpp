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

static const double SOLAR_MASS = 39.47841760435743;
static const double DAYS_PER_YEAR = 365.24;
static const int64_t N = 20000LL;
static const int64_t NBODIES = 5LL;
static const double DT = 0.01;

struct Ruby_Planet {
  struct Impl {
    double iv_x = 0.0;
    double iv_y = 0.0;
    double iv_z = 0.0;
    double iv_vx = 0.0;
    double iv_vy = 0.0;
    double iv_vz = 0.0;
    double iv_mass = 0.0;
  };
  std::shared_ptr<Impl> p;

  Ruby_Planet() = default;
  Ruby_Planet(const RubyNil&) {}
  Ruby_Planet(auto x, auto y, auto z, auto vx, auto vy, auto vz, auto mass) : p(std::make_shared<Impl>()) {
    auto _t1_0 = x;
    auto _t1_1 = y;
    auto _t1_2 = z;
    p->iv_x = _t1_0;
    p->iv_y = _t1_1;
    p->iv_z = _t1_2;
    auto _t2_0 = (vx * DAYS_PER_YEAR);
    auto _t2_1 = (vy * DAYS_PER_YEAR);
    auto _t2_2 = (vz * DAYS_PER_YEAR);
    p->iv_vx = _t2_0;
    p->iv_vy = _t2_1;
    p->iv_vz = _t2_2;
    p->iv_mass = (mass * SOLAR_MASS);
  }

  auto x() {
    return p->iv_x;
  }

  auto set_x(auto __anon_req__) {
    p->iv_x = __anon_req__;
    return p->iv_x;
  }

  auto y() {
    return p->iv_y;
  }

  auto set_y(auto __anon_req__) {
    p->iv_y = __anon_req__;
    return p->iv_y;
  }

  auto z() {
    return p->iv_z;
  }

  auto set_z(auto __anon_req__) {
    p->iv_z = __anon_req__;
    return p->iv_z;
  }

  auto vx() {
    return p->iv_vx;
  }

  auto set_vx(auto __anon_req__) {
    p->iv_vx = __anon_req__;
    return p->iv_vx;
  }

  auto vy() {
    return p->iv_vy;
  }

  auto set_vy(auto __anon_req__) {
    p->iv_vy = __anon_req__;
    return p->iv_vy;
  }

  auto vz() {
    return p->iv_vz;
  }

  auto set_vz(auto __anon_req__) {
    p->iv_vz = __anon_req__;
    return p->iv_vz;
  }

  auto mass() {
    return p->iv_mass;
  }

  auto set_mass(auto __anon_req__) {
    p->iv_mass = __anon_req__;
    return p->iv_mass;
  }

  auto move_from_i(auto bodies, auto nbodies, auto dt, auto i) {
    std::decay_t<decltype(bodies[i])> b2{};
    std::decay_t<decltype((p->iv_x - b2.x()))> dx{};
    std::decay_t<decltype((p->iv_y - b2.y()))> dy{};
    std::decay_t<decltype((p->iv_z - b2.z()))> dz{};
    std::decay_t<decltype((((dx * dx) + (dy * dy)) + (dz * dz)))> dsq{};
    std::decay_t<decltype((dt / (dsq * sqrt(dsq))))> mag{};
    std::decay_t<decltype((p->iv_mass * mag))> b_mass_mag{};
    std::decay_t<decltype((b2.mass() * mag))> b2_mass_mag{};
    while ((i < nbodies)) {
      (b2 = bodies[i]);
      (dx = (p->iv_x - b2.x()));
      (dy = (p->iv_y - b2.y()));
      (dz = (p->iv_z - b2.z()));
      (dsq = (((dx * dx) + (dy * dy)) + (dz * dz)));
      (mag = (dt / (dsq * sqrt(dsq))));
      auto _t3_0 = (p->iv_mass * mag);
      auto _t3_1 = (b2.mass() * mag);
      b_mass_mag = _t3_0;
      b2_mass_mag = _t3_1;
      p->iv_vx = (p->iv_vx - (dx * b2_mass_mag));
      p->iv_vy = (p->iv_vy - (dy * b2_mass_mag));
      p->iv_vz = (p->iv_vz - (dz * b2_mass_mag));
      b2.add_v((dx * b_mass_mag), (dy * b_mass_mag), (dz * b_mass_mag));
      (i = (i + INT64_C(1)));
    }
    p->iv_x = (p->iv_x + (dt * p->iv_vx));
    p->iv_y = (p->iv_y + (dt * p->iv_vy));
    return p->iv_z = (p->iv_z + (dt * p->iv_vz));
  }

  auto add_v(auto dx, auto dy, auto dz) {
    p->iv_vx = (p->iv_vx + dx);
    p->iv_vy = (p->iv_vy + dy);
    return p->iv_vz = (p->iv_vz + dz);
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_Planet>() { return "Planet"; }



static auto energy(auto bodies) {
  double e = 0.0;
  std::decay_t<decltype(bodies.len())> nbodies{};
  (e = 0.0);
  (nbodies = bodies.len());
  for (int64_t i = INT64_C(0); i < nbodies; i++) {
    auto b = bodies[i];
    (e = (e + ((0.5 * b.mass()) * (((b.vx() * b.vx()) + (b.vy() * b.vy())) + (b.vz() * b.vz())))));
    for (int64_t j = (i + INT64_C(1)); j < nbodies; j++) {
    auto b2 = bodies[j];
    auto dx = (b.x() - b2.x());
    auto dy = (b.y() - b2.y());
    auto dz = (b.z() - b2.z());
    auto distance = sqrt((((dx * dx) + (dy * dy)) + (dz * dz)));
    (e = (e - ((b.mass() * b2.mass()) / distance)));
  };
  }
  return e;
}

static auto offset_momentum(auto bodies) {
  double px = 0.0;
  double py = 0.0;
  double pz = 0.0;
  std::decay_t<decltype(bodies[INT64_C(0)])> b{};
  auto _t4_0 = 0.0;
  auto _t4_1 = 0.0;
  auto _t4_2 = 0.0;
  px = _t4_0;
  py = _t4_1;
  pz = _t4_2;
  for (int64_t _fi = 0; _fi < (bodies).len(); _fi++) {
    b = (bodies)[_fi];
    auto m = b.mass();
    (px = (px + (b.vx() * m)));
    (py = (py + (b.vy() * m)));
    (pz = (pz + (b.vz() * m)));
  }
  (b = bodies[INT64_C(0)]);
  b.set_vx(((-(px)) / SOLAR_MASS));
  b.set_vy(((-(py)) / SOLAR_MASS));
  return b.set_vz(((-(pz)) / SOLAR_MASS));
}


int main() {
  double last_x = 0.0;
  std::decay_t<decltype(NBODIES)> nbodies{};
  std::decay_t<decltype(N)> n{};
  double dt = 0.0;
  RubyArray<Ruby_Planet> bodies;
  int64_t i = 0;
  std::decay_t<decltype(bodies[i])> b{};
  (last_x = 0.0);
  for (int64_t _i = 0; _i < INT64_C(100); _i++) {
    (nbodies = NBODIES);
    (n = N);
    (dt = DT);
    (bodies = ({ auto _e0 = Ruby_Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0); auto _a = RubyArray<decltype(_e0)>(5); _a[0] = _e0; _a[1] = Ruby_Planet(4.841431442464721, -1.1603200440274284, -0.10362204447112311, 0.001660076642744037, 0.007699011184197404, -6.90460016972063e-05, 0.0009547919384243266); _a[2] = Ruby_Planet(8.34336671824458, 4.124798564124305, -0.4035234171143214, -0.002767425107268624, 0.004998528012349172, 2.3041729757376393e-05, 0.0002858859806661308); _a[3] = Ruby_Planet(12.894369562139131, -15.111151401698631, -0.22330757889265573, 0.002964601375647616, 0.0023784717395948095, -2.9658956854023756e-05, 4.366244043351563e-05); _a[4] = Ruby_Planet(15.379697114850917, -25.919314609987964, 0.17925877295037118, 0.0026806777249038932, 0.001628241700382423, -9.515922545197159e-05, 5.1513890204661145e-05); _a; }));
    offset_momentum(bodies);
    for (int64_t _i = 0; _i < n; _i++) {
      (i = INT64_C(0));
      while ((i < nbodies)) {
        (b = bodies[i]);
        b.move_from_i(bodies, nbodies, dt, (i + INT64_C(1)));
        (i = (i + INT64_C(1)));
      };
    };
    (last_x = bodies[INT64_C(0)].x());
  }
  ruby_puts(last_x);
  return 0;
}
