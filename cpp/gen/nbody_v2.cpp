#include "../runtime/frozone.hpp"

// ── New object model: Ruby_Planet inherits from RubyKernelObject ────
// Ivars are direct fields (no Impl indirection).
// Pointer = Ruby reference. nullptr = nil. No shared_ptr.

static const double SOLAR_MASS = 39.47841760435743;
static const double DAYS_PER_YEAR = 365.24;
static const int64_t N = 20000LL;
static const int64_t NBODIES = 5LL;
static const double DT = 0.01;

struct Ruby_Planet : public RubyObject {
  double iv_x = 0.0, iv_y = 0.0, iv_z = 0.0;
  double iv_vx = 0.0, iv_vy = 0.0, iv_vz = 0.0;
  double iv_mass = 0.0;

  Ruby_Planet(double x, double y, double z,
              double vx, double vy, double vz, double mass) {
    iv_x = x; iv_y = y; iv_z = z;
    auto _vx = vx * DAYS_PER_YEAR;
    auto _vy = vy * DAYS_PER_YEAR;
    auto _vz = vz * DAYS_PER_YEAR;
    iv_vx = _vx; iv_vy = _vy; iv_vz = _vz;
    iv_mass = mass * SOLAR_MASS;
  }

  const char* rb_class_name() const override { return "Planet"; }

  double x() const { return iv_x; }
  double y() const { return iv_y; }
  double z() const { return iv_z; }
  double vx() const { return iv_vx; }
  double vy() const { return iv_vy; }
  double vz() const { return iv_vz; }
  double mass() const { return iv_mass; }
  void set_x(double v) { iv_x = v; }
  void set_y(double v) { iv_y = v; }
  void set_z(double v) { iv_z = v; }
  void set_vx(double v) { iv_vx = v; }
  void set_vy(double v) { iv_vy = v; }
  void set_vz(double v) { iv_vz = v; }
  void set_mass(double v) { iv_mass = v; }

  void move_from_i(RubyArray<Ruby_Planet*>& bodies, int64_t nbodies, double dt, int64_t i) {
    while (i < nbodies) {
      Ruby_Planet* b2 = (*bodies.data)[i];
      double dx = iv_x - b2->iv_x;
      double dy = iv_y - b2->iv_y;
      double dz = iv_z - b2->iv_z;
      // distance computed above via dsq
      double dsq = dx * dx + dy * dy + dz * dz;
      double distance = sqrt(dsq);
      double mag = ruby_div(dt, (dsq * sqrt(dsq)));
      double b_m_mag = iv_mass * mag;
      double b2_m_mag = b2->iv_mass * mag;
      iv_vx -= dx * b2_m_mag;
      iv_vy -= dy * b2_m_mag;
      iv_vz -= dz * b2_m_mag;
      b2->iv_vx += dx * b_m_mag;
      b2->iv_vy += dy * b_m_mag;
      b2->iv_vz += dz * b_m_mag;
      i++;
    }
    iv_x += dt * iv_vx;
    iv_y += dt * iv_vy;
    iv_z += dt * iv_vz;
  }
};

static void offset_momentum(RubyArray<Ruby_Planet*>& bodies) {
  double px = 0.0, py = 0.0, pz = 0.0;
  for (auto& b : *bodies.data) {
    px += b->iv_vx * b->iv_mass;
    py += b->iv_vy * b->iv_mass;
    pz += b->iv_vz * b->iv_mass;
  }
  (*bodies.data)[0]->iv_vx = ruby_div(-px, SOLAR_MASS);
  (*bodies.data)[0]->iv_vy = ruby_div(-py, SOLAR_MASS);
  (*bodies.data)[0]->iv_vz = ruby_div(-pz, SOLAR_MASS);
}

int main() {
  FROZONE_GC_INIT();
  double last_x = 0.0;
  for (int64_t _i = 0; _i < 100; _i++) {
    int64_t nbodies = NBODIES;
    double dt = DT;

    // Build bodies array — raw pointers, no shared_ptr
    auto bodies = RubyArray<Ruby_Planet*>(5);
    bodies[0] = new Ruby_Planet(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
    bodies[1] = new Ruby_Planet(4.84143144246472090e+00, -1.16032004402742839e+00, -1.03622044471123109e-01, 1.66007664274403694e-03, 7.69901118419740425e-03, -6.90460016972063023e-05, 9.54791938424326609e-04);
    bodies[2] = new Ruby_Planet(8.34336671824457987e+00, 4.12479856412430479e+00, -4.03523417114321381e-01, -2.76742510726862411e-03, 4.99852801234917238e-03, 2.30417297573763929e-05, 2.85885980666130812e-04);
    bodies[3] = new Ruby_Planet(1.28943695621391310e+01, -1.51111514016986312e+01, -2.23307578892655734e-01, 2.96460137564761618e-03, 2.37847173959480950e-03, -2.96589568540237556e-05, 4.36624404335156298e-05);
    bodies[4] = new Ruby_Planet(1.53796971148509165e+01, -2.59193146099879641e+01, 1.79258772950371181e-01, 2.68067772490389322e-03, 1.62824170038242295e-03, -9.51592254519715870e-05, 5.15138902046611451e-05);

    offset_momentum(bodies);

    for (int64_t _n = 0; _n < N; _n++) {
      int64_t i = 0;
      while (i < nbodies) {
        Ruby_Planet* b = (*bodies.data)[i];
        b->move_from_i(bodies, nbodies, dt, i + 1);
        i++;
      }
    }
    last_x = bodies[0]->x();

    // Leak for now — GC will handle this later
  }
  ruby_puts(last_x);
  return 0;
}
