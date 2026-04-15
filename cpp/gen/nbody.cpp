#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>

// --- Frozone C++ runtime (minimal) ---

class RubyObject {
public:
  virtual ~RubyObject() = default;
  virtual int64_t to_i64() { return 0; }
  virtual double to_f64() { return 0.0; }
  virtual const char* to_s() { return "#<Object>"; }
  virtual bool truthy() { return true; }
};

class RubyNil : public RubyObject {
public:
  bool truthy() override { return false; }
  const char* to_s() override { return ""; }
};

class RubyInteger : public RubyObject {
public:
  int64_t value;
  RubyInteger(int64_t v) : value(v) {}
  int64_t to_i64() override { return value; }
  const char* to_s() override {
    static thread_local char buf[32];
    snprintf(buf, sizeof(buf), "%lld", (long long)value);
    return buf;
  }
};

class RubyFloat : public RubyObject {
public:
  double value;
  RubyFloat(double v) : value(v) {}
  double to_f64() override { return value; }
  int64_t to_i64() override { return (int64_t)value; }
};

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

static constexpr int64_t RUBY_NIL = 0;

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


struct Ruby_Planet {
  int64_t iv_mass = 0;

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
      auto b2 = bodies[i];
      auto dx = (iv_x - b2.x());
      auto dy = (iv_y - b2.y());
      auto dz = (iv_z - b2.z());
      auto dsq = (((dx * dx) + (dy * dy)) + (dz * dz));
      auto mag = (dt / (dsq * sqrt(dsq)));
      b_mass_mag = (iv_mass * mag); b2_mass_mag = (b2.mass() * mag);
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

  auto run_benchmark() {
    return 0LL;
  }

  auto energy(auto bodies) {
    double e = 0.0;
    auto nbodies = bodies.len;
    for (int64_t i = 0; i < nbodies; i++) {
      auto b = bodies[i];
      e = (e + ((0.5 * b.mass()) * (((b.vx() * b.vx()) + (b.vy() * b.vy())) + (b.vz() * b.vz()))));
      for (int64_t j = 0; j < nbodies; j++) {
      auto b2 = bodies[j];
      auto dx = (b.x() - b2.x());
      auto dy = (b.y() - b2.y());
      auto dz = (b.z() - b2.z());
      auto distance = sqrt((((dx * dx) + (dy * dy)) + (dz * dz)));
      e = (e - ((b.mass() * b2.mass()) / distance));
    };
    }
    return e;
  }

  auto offset_momentum(auto bodies) {
    px = 0.0; py = 0.0; pz = 0.0;
    for (int64_t b = 0; b < bodies; b++) {
      auto m = b.mass();
      auto px = (px + (b.vx() * m));
      auto py = (py + (b.vy() * m));
      auto pz = (pz + (b.vz() * m));
    }
    b = bodies[INT64_C(0)];
    b.set_vx((px.-@() / SOLAR_MASS));
    b.set_vy((py.-@() / SOLAR_MASS));
    return b.set_vz((pz.-@() / SOLAR_MASS));
  }

  Ruby_Planet(int64_t x, int64_t y, int64_t z, int64_t vx, int64_t vy, int64_t vz, int64_t mass) {
    @x = x; @y = y; @z = z;
    @vx = (vx * DAYS_PER_YEAR); @vy = (vy * DAYS_PER_YEAR); @vz = (vz * DAYS_PER_YEAR);
    iv_mass = (mass * SOLAR_MASS);
  }
};


static const double SOLAR_MASS = 39.47841760435743;
static const double DAYS_PER_YEAR = 365.24;
static Ruby_Array BODIES;
static const int64_t N = 20000LL;
static const int64_t NBODIES = 5LL;
static const double DT = 0.01;

static auto energy(auto bodies) {
  double e = 0.0;
  auto nbodies = bodies.len;
  for (int64_t i = 0; i < nbodies; i++) {
    auto b = bodies[i];
    e = (e + ((0.5 * b.mass()) * (((b.vx() * b.vx()) + (b.vy() * b.vy())) + (b.vz() * b.vz()))));
    for (int64_t j = 0; j < nbodies; j++) {
    auto b2 = bodies[j];
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
  px = 0.0; py = 0.0; pz = 0.0;
  for (int64_t b = 0; b < bodies; b++) {
    auto m = b.mass();
    auto px = (px + (b.vx() * m));
    auto py = (py + (b.vy() * m));
    auto pz = (pz + (b.vz() * m));
  }
  b = bodies[INT64_C(0)];
  b.set_vx((px.-@() / SOLAR_MASS));
  b.set_vy((py.-@() / SOLAR_MASS));
  return b.set_vz((pz.-@() / SOLAR_MASS));
}


int main() {
  double last_x = 0.0;
  for (int64_t _i = 0; _i < INT64_C(100); _i++) {
    int64_t nbodies = NBODIES;
    int64_t n = N;
    int64_t dt = DT;
    auto bodies = ({ auto _e0 = Ruby_Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0); auto _a = RubyArray<decltype(_e0)>(5); _a[0] = _e0; _a[1] = Ruby_Planet(4.841431442464721, -1.1603200440274284, -0.10362204447112311, 0.001660076642744037, 0.007699011184197404, -6.90460016972063e-05, 0.0009547919384243266); _a[2] = Ruby_Planet(8.34336671824458, 4.124798564124305, -0.4035234171143214, -0.002767425107268624, 0.004998528012349172, 2.3041729757376393e-05, 0.0002858859806661308); _a[3] = Ruby_Planet(12.894369562139131, -15.111151401698631, -0.22330757889265573, 0.002964601375647616, 0.0023784717395948095, -2.9658956854023756e-05, 4.366244043351563e-05); _a[4] = Ruby_Planet(15.379697114850917, -25.919314609987964, 0.17925877295037118, 0.0026806777249038932, 0.001628241700382423, -9.515922545197159e-05, 5.1513890204661145e-05); _a; });
    offset_momentum(bodies);
    for (int64_t _i = 0; _i < n; _i++) {
      int64_t i = INT64_C(0);
      while ((i < nbodies)) {
        auto b = bodies[i];
        b.move_from_i(bodies, nbodies, dt, (i + INT64_C(1)));
        i = (i + INT64_C(1));
      };
    };
    last_x = bodies[INT64_C(0)].x();
  }
  ruby_puts(last_x);
  return 0;
}
