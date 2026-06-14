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

static RubyNil RUBY_NIL_INSTANCE;
static RubyObject* RUBY_NIL = &RUBY_NIL_INSTANCE;


struct Ruby_Planet {
  int64_t mass = 0;

  int64_t x() {
    return x;
  }

  int64_t x=(int64_t __anon_req__) {
    return x = __anon_req__;
  }

  int64_t y() {
    return y;
  }

  int64_t y=(int64_t __anon_req__) {
    return y = __anon_req__;
  }

  int64_t z() {
    return z;
  }

  int64_t z=(int64_t __anon_req__) {
    return z = __anon_req__;
  }

  int64_t vx() {
    return vx;
  }

  int64_t vx=(int64_t __anon_req__) {
    return vx = __anon_req__;
  }

  int64_t vy() {
    return vy;
  }

  int64_t vy=(int64_t __anon_req__) {
    return vy = __anon_req__;
  }

  int64_t vz() {
    return vz;
  }

  int64_t vz=(int64_t __anon_req__) {
    return vz = __anon_req__;
  }

  int64_t mass() {
    return mass;
  }

  int64_t mass=(int64_t __anon_req__) {
    return mass = __anon_req__;
  }

  int64_t move_from_i(int64_t bodies, int64_t nbodies, int64_t dt, int64_t i) {
    while ((i < nbodies)) {
      int64_t b2 = bodies[i];
      int64_t dx = (x - b2.x());
      int64_t dy = (y - b2.y());
      int64_t dz = (z - b2.z());
      int64_t dsq = (((dx * dx) + (dy * dy)) + (dz * dz));
      int64_t mag = (dt / (dsq * sqrt(dsq)));
      b_mass_mag = (mass * mag); b2_mass_mag = (b2.mass() * mag);
      vx = (vx - (dx * b2_mass_mag));
      vy = (vy - (dy * b2_mass_mag));
      vz = (vz - (dz * b2_mass_mag));
      b2.add_v((dx * b_mass_mag), (dy * b_mass_mag), (dz * b_mass_mag));
      i = (i + 1LL);
    }
    x = (x + (dt * vx));
    y = (y + (dt * vy));
    return z = (z + (dt * vz));
  }

  int64_t add_v(int64_t dx, int64_t dy, int64_t dz) {
    vx = (vx + dx);
    vy = (vy + dy);
    return vz = (vz + dz);
  }

  int64_t energy(int64_t bodies) {
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

  int64_t offset_momentum(int64_t bodies) {
    px = 0.0; py = 0.0; pz = 0.0;
    for (int64_t b = 0; b < bodies; b++) {
      int64_t m = b.mass();
      int64_t px = (px + (b.vx() * m));
      int64_t py = (py + (b.vy() * m));
      int64_t pz = (pz + (b.vz() * m));
    }
    b = bodies[0LL];
    b.vx=((px.-@() / SOLAR_MASS));
    b.vy=((py.-@() / SOLAR_MASS));
    return b.vz=((pz.-@() / SOLAR_MASS));
  }

  Ruby_Planet(int64_t x, int64_t y, int64_t z, int64_t vx, int64_t vy, int64_t vz, int64_t mass) {
    @x = x; @y = y; @z = z;
    @vx = (vx * DAYS_PER_YEAR); @vy = (vy * DAYS_PER_YEAR); @vz = (vz * DAYS_PER_YEAR);
    mass = (mass * SOLAR_MASS);
  }
};


static const double SOLAR_MASS = 39.47841760435743;
static const double DAYS_PER_YEAR = 365.24;
static Ruby_Array BODIES;
static const int64_t N = 20000LL;
static const int64_t NBODIES = 5LL;
static const double DT = 0.01;

static int64_t energy(int64_t bodies) {
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

static int64_t offset_momentum(int64_t bodies) {
  px = 0.0; py = 0.0; pz = 0.0;
  for (int64_t b = 0; b < bodies; b++) {
    int64_t m = b.mass();
    int64_t px = (px + (b.vx() * m));
    int64_t py = (py + (b.vy() * m));
    int64_t pz = (pz + (b.vz() * m));
  }
  b = bodies[0LL];
  b.vx=((px.-@() / SOLAR_MASS));
  b.vy=((py.-@() / SOLAR_MASS));
  return b.vz=((pz.-@() / SOLAR_MASS));
}


int main() {
  int64_t last_x = 0.0;
  for (int64_t _i = 0; _i < 100LL; _i++) {
    int64_t nbodies = NBODIES;
    int64_t n = N;
    int64_t dt = DT;
    int64_t bodies = /* UNSUPPORTED: ArrayLiteral */;
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
