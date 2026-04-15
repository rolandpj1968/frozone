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

static const double SOLAR_MASS = 39.47841760435743;
static const double DAYS_PER_YEAR = 365.24;
static const int64_t N = 20000LL;
static const int64_t NBODIES = 5LL;
static const double DT = 0.01;

struct Ruby_Planet {
  double iv_x;
  double iv_y;
  double iv_z;
  double iv_vx;
  double iv_vy;
  double iv_vz;
  double iv_mass;

  auto x() {
    return iv_x;
  }

  auto set_x(auto __anon_req__) {
    iv_x = __anon_req__;
    return iv_x;
  }

  auto y() {
    return iv_y;
  }

  auto set_y(auto __anon_req__) {
    iv_y = __anon_req__;
    return iv_y;
  }

  auto z() {
    return iv_z;
  }

  auto set_z(auto __anon_req__) {
    iv_z = __anon_req__;
    return iv_z;
  }

  auto vx() {
    return iv_vx;
  }

  auto set_vx(auto __anon_req__) {
    iv_vx = __anon_req__;
    return iv_vx;
  }

  auto vy() {
    return iv_vy;
  }

  auto set_vy(auto __anon_req__) {
    iv_vy = __anon_req__;
    return iv_vy;
  }

  auto vz() {
    return iv_vz;
  }

  auto set_vz(auto __anon_req__) {
    iv_vz = __anon_req__;
    return iv_vz;
  }

  auto mass() {
    return iv_mass;
  }

  auto set_mass(auto __anon_req__) {
    iv_mass = __anon_req__;
    return iv_mass;
  }

  auto move_from_i(auto bodies, auto nbodies, auto dt, auto i) {
    while ((i < nbodies)) {
      auto& b2 = bodies[i];
      auto dx = (iv_x - b2.x());
      auto dy = (iv_y - b2.y());
      auto dz = (iv_z - b2.z());
      auto dsq = (((dx * dx) + (dy * dy)) + (dz * dz));
      auto mag = (dt / (dsq * sqrt(dsq)));
      auto b_mass_mag = (iv_mass * mag); auto b2_mass_mag = (b2.mass() * mag);
      iv_vx = (iv_vx - (dx * b2_mass_mag));
      iv_vy = (iv_vy - (dy * b2_mass_mag));
      iv_vz = (iv_vz - (dz * b2_mass_mag));
      b2.add_v((dx * b_mass_mag), (dy * b_mass_mag), (dz * b_mass_mag));
      i = (i + INT64_C(1));
    }
    iv_x = (iv_x + (dt * iv_vx));
    iv_y = (iv_y + (dt * iv_vy));
    return iv_z = (iv_z + (dt * iv_vz));
  }

  auto add_v(auto dx, auto dy, auto dz) {
    iv_vx = (iv_vx + dx);
    iv_vy = (iv_vy + dy);
    return iv_vz = (iv_vz + dz);
  }

  Ruby_Planet() = default;
  Ruby_Planet(auto x, auto y, auto z, auto vx, auto vy, auto vz, auto mass) {
    iv_x = x; iv_y = y; iv_z = z;
    iv_vx = (vx * DAYS_PER_YEAR); iv_vy = (vy * DAYS_PER_YEAR); iv_vz = (vz * DAYS_PER_YEAR);
    iv_mass = (mass * SOLAR_MASS);
  }
};



static auto energy(auto bodies) {
  double e = 0.0;
  auto nbodies = bodies.len();
  for (int64_t i = INT64_C(0); i < nbodies; i++) {
    auto& b = bodies[i];
    e = (e + ((0.5 * b.mass()) * (((b.vx() * b.vx()) + (b.vy() * b.vy())) + (b.vz() * b.vz()))));
    for (int64_t j = (i + INT64_C(1)); j < nbodies; j++) {
    auto& b2 = bodies[j];
    auto dx = (b.x() - b2.x());
    auto dy = (b.y() - b2.y());
    auto dz = (b.z() - b2.z());
    auto distance = sqrt((((dx * dx) + (dy * dy)) + (dz * dz)));
    e = (e - ((b.mass() * b2.mass()) / distance));
  };
  }
  return e;
}

static auto offset_momentum(auto bodies) {
  auto px = 0.0; auto py = 0.0; auto pz = 0.0;
  std::remove_reference_t<decltype((bodies)[0])> b; for (int64_t _fi = 0; _fi < (bodies).len(); _fi++) {
    b = (bodies)[_fi];
    auto m = b.mass();
    px = (px + (b.vx() * m));
    py = (py + (b.vy() * m));
    pz = (pz + (b.vz() * m));
  }
  b = bodies[INT64_C(0)];
  b.set_vx(((-(px)) / SOLAR_MASS));
  b.set_vy(((-(py)) / SOLAR_MASS));
  return b.set_vz(((-(pz)) / SOLAR_MASS));
}


int main() {
  double last_x = 0.0;
  for (int64_t _i = 0; _i < INT64_C(100); _i++) {
    auto nbodies = NBODIES;
    auto n = N;
    double dt = DT;
    auto bodies = ({ auto _e0 = Ruby_Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0); auto _a = RubyArray<decltype(_e0)>(5); _a[0] = _e0; _a[1] = Ruby_Planet(4.841431442464721, -1.1603200440274284, -0.10362204447112311, 0.001660076642744037, 0.007699011184197404, -6.90460016972063e-05, 0.0009547919384243266); _a[2] = Ruby_Planet(8.34336671824458, 4.124798564124305, -0.4035234171143214, -0.002767425107268624, 0.004998528012349172, 2.3041729757376393e-05, 0.0002858859806661308); _a[3] = Ruby_Planet(12.894369562139131, -15.111151401698631, -0.22330757889265573, 0.002964601375647616, 0.0023784717395948095, -2.9658956854023756e-05, 4.366244043351563e-05); _a[4] = Ruby_Planet(15.379697114850917, -25.919314609987964, 0.17925877295037118, 0.0026806777249038932, 0.001628241700382423, -9.515922545197159e-05, 5.1513890204661145e-05); _a; });
    offset_momentum(bodies);
    for (int64_t _i = 0; _i < n; _i++) {
      int64_t i = INT64_C(0);
      while ((i < nbodies)) {
        auto& b = bodies[i];
        b.move_from_i(bodies, nbodies, dt, (i + INT64_C(1)));
        i = (i + INT64_C(1));
      };
    };
    last_x = bodies[INT64_C(0)].x();
  }
  ruby_puts(last_x);
  return 0;
}
