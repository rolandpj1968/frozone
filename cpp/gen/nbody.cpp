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

// Native Int64 array — TI-specialised, no boxing
class RubyArray_I64 {
public:
  int64_t* data;
  int64_t len;
  RubyArray_I64(int64_t size, int64_t fill = 0) : len(size) {
    data = (int64_t*)calloc(size, sizeof(int64_t));
    if (fill) for (int64_t i = 0; i < size; i++) data[i] = fill;
  }
  int64_t& operator[](int64_t i) { return data[i]; }
  ~RubyArray_I64() { free(data); }
};

// Native Float64 array
class RubyArray_F64 {
public:
  double* data;
  int64_t len;
  RubyArray_F64(int64_t size = 0, double fill = 0.0) : len(size) {
    data = (double*)calloc(size > 0 ? size : 1, sizeof(double));
    if (fill != 0.0) for (int64_t i = 0; i < size; i++) data[i] = fill;
  }
  double& operator[](int64_t i) { return data[i]; }
  ~RubyArray_F64() { free(data); }
};

static constexpr int64_t RUBY_NIL = 0;


struct Ruby_Planet {
  int64_t iv_mass = 0;

  int64_t x() {
    return iv_x;
  }

  int64_t set_x(auto __anon_req__) {
    iv_x = __anon_req__;
    return iv_x;
  }

  int64_t y() {
    return iv_y;
  }

  int64_t set_y(auto __anon_req__) {
    iv_y = __anon_req__;
    return iv_y;
  }

  int64_t z() {
    return iv_z;
  }

  int64_t set_z(auto __anon_req__) {
    iv_z = __anon_req__;
    return iv_z;
  }

  int64_t vx() {
    return iv_vx;
  }

  int64_t set_vx(auto __anon_req__) {
    iv_vx = __anon_req__;
    return iv_vx;
  }

  int64_t vy() {
    return iv_vy;
  }

  int64_t set_vy(auto __anon_req__) {
    iv_vy = __anon_req__;
    return iv_vy;
  }

  int64_t vz() {
    return iv_vz;
  }

  int64_t set_vz(auto __anon_req__) {
    iv_vz = __anon_req__;
    return iv_vz;
  }

  int64_t mass() {
    return iv_mass;
  }

  int64_t set_mass(auto __anon_req__) {
    iv_mass = __anon_req__;
    return iv_mass;
  }

  int64_t move_from_i(auto bodies, auto nbodies, auto dt, auto i) {
    while ((i < nbodies)) {
      int64_t b2 = bodies[i];
      int64_t dx = (iv_x - b2.x());
      int64_t dy = (iv_y - b2.y());
      int64_t dz = (iv_z - b2.z());
      int64_t dsq = (((dx * dx) + (dy * dy)) + (dz * dz));
      int64_t mag = (dt / (dsq * sqrt(dsq)));
      b_mass_mag = (iv_mass * mag); b2_mass_mag = (b2.mass() * mag);
      iv_vx = (iv_vx - (dx * b2_mass_mag));
      iv_vy = (iv_vy - (dy * b2_mass_mag));
      iv_vz = (iv_vz - (dz * b2_mass_mag));
      b2.add_v((dx * b_mass_mag), (dy * b_mass_mag), (dz * b_mass_mag));
      i = (i + 1LL);
    }
    iv_x = (iv_x + (dt * iv_vx));
    iv_y = (iv_y + (dt * iv_vy));
    return iv_z = (iv_z + (dt * iv_vz));
  }

  int64_t add_v(auto dx, auto dy, auto dz) {
    iv_vx = (iv_vx + dx);
    iv_vy = (iv_vy + dy);
    return iv_vz = (iv_vz + dz);
  }

  int64_t run_benchmark() {
    return 0LL;
  }

  int64_t energy(auto bodies) {
    int64_t e = 0.0;
    int64_t nbodies = bodies.len;
    for (int64_t i = 0; i < nbodies; i++) {
      int64_t b = bodies[i];
      e = (e + ((0.5 * b.mass()) * (((b.vx() * b.vx()) + (b.vy() * b.vy())) + (b.vz() * b.vz()))));
      for (int64_t j = 0; j < nbodies; j++) {
      int64_t b2 = bodies[j];
      int64_t dx = (b.x() - b2.x());
      int64_t dy = (b.y() - b2.y());
      int64_t dz = (b.z() - b2.z());
      int64_t distance = sqrt((((dx * dx) + (dy * dy)) + (dz * dz)));
      e = (e - ((b.mass() * b2.mass()) / distance));
    };
    }
    return e;
  }

  int64_t offset_momentum(auto bodies) {
    px = 0.0; py = 0.0; pz = 0.0;
    for (int64_t b = 0; b < bodies; b++) {
      int64_t m = b.mass();
      int64_t px = (px + (b.vx() * m));
      int64_t py = (py + (b.vy() * m));
      int64_t pz = (pz + (b.vz() * m));
    }
    b = bodies[0LL];
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

static int64_t energy(auto bodies) {
  int64_t e = 0.0;
  int64_t nbodies = bodies.len;
  for (int64_t i = 0; i < nbodies; i++) {
    int64_t b = bodies[i];
    e = (e + ((0.5 * b.mass()) * (((b.vx() * b.vx()) + (b.vy() * b.vy())) + (b.vz() * b.vz()))));
    for (int64_t j = 0; j < nbodies; j++) {
    int64_t b2 = bodies[j];
    int64_t dx = (b.x() - b2.x());
    int64_t dy = (b.y() - b2.y());
    int64_t dz = (b.z() - b2.z());
    int64_t distance = sqrt((((dx * dx) + (dy * dy)) + (dz * dz)));
    e = (e - ((b.mass() * b2.mass()) / distance));
  };
  }
  return e;
}

static int64_t offset_momentum(auto bodies) {
  px = 0.0; py = 0.0; pz = 0.0;
  for (int64_t b = 0; b < bodies; b++) {
    int64_t m = b.mass();
    int64_t px = (px + (b.vx() * m));
    int64_t py = (py + (b.vy() * m));
    int64_t pz = (pz + (b.vz() * m));
  }
  b = bodies[0LL];
  b.set_vx((px.-@() / SOLAR_MASS));
  b.set_vy((py.-@() / SOLAR_MASS));
  return b.set_vz((pz.-@() / SOLAR_MASS));
}


int main() {
  int64_t last_x = 0.0;
  for (int64_t _i = 0; _i < 100LL; _i++) {
    int64_t nbodies = NBODIES;
    int64_t n = N;
    int64_t dt = DT;
    int64_t bodies = ({ auto _a = RubyArray_I64(5); _a[0] = Ruby_Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0); _a[1] = Ruby_Planet(4.841431442464721, -1.1603200440274284, -0.10362204447112311, 0.001660076642744037, 0.007699011184197404, -6.90460016972063e-05, 0.0009547919384243266); _a[2] = Ruby_Planet(8.34336671824458, 4.124798564124305, -0.4035234171143214, -0.002767425107268624, 0.004998528012349172, 2.3041729757376393e-05, 0.0002858859806661308); _a[3] = Ruby_Planet(12.894369562139131, -15.111151401698631, -0.22330757889265573, 0.002964601375647616, 0.0023784717395948095, -2.9658956854023756e-05, 4.366244043351563e-05); _a[4] = Ruby_Planet(15.379697114850917, -25.919314609987964, 0.17925877295037118, 0.0026806777249038932, 0.001628241700382423, -9.515922545197159e-05, 5.1513890204661145e-05); _a; });
    offset_momentum(bodies);
    for (int64_t _i = 0; _i < n; _i++) {
      int64_t i = 0LL;
      while ((i < nbodies)) {
        int64_t b = bodies[i];
        b.move_from_i(bodies, nbodies, dt, (i + 1LL));
        i = (i + 1LL);
      };
    };
    last_x = bodies[0LL].x();
  }
  printf("%lld\n", (long long)(last_x));
  return 0;
}
