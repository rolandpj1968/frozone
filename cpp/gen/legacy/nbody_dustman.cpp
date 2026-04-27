// nbody_dustman.cpp — abstraction-layer smoke test.
//
// Same logic as cpp/gen/nbody.cpp, but written against the gc_ref / gc_local /
// gc_new abstractions from cpp/runtime/frozone.hpp. Compiles under all three
// GC modes:
//   no flags         — plain new (leaks)
//   -DFROZONE_USE_BOEHM_GC   — Boehm GC (drop-in operator-new override)
//   -DFROZONE_USE_DUSTMAN_GC — Dustman precise GC (via gc_local + Tracer)
//
// Serves as the model for what the emitter should produce for user classes.

#include "../runtime/frozone.hpp"

static const double SOLAR_MASS = 39.47841760435743;
static const double DAYS_PER_YEAR = 365.24;
static const int64_t N = 20000LL;
static const int64_t NBODIES = 5LL;
static const double DT = 0.01;

struct Ruby_Planet : public RubyObject {
  double iv_x = 0.0, iv_y = 0.0, iv_z = 0.0;
  double iv_vx = 0.0, iv_vy = 0.0, iv_vz = 0.0;
  double iv_mass = 0.0;

  Ruby_Planet() = default;
  Ruby_Planet(double x, double y, double z, double vx, double vy, double vz, double mass)
      : iv_x(x), iv_y(y), iv_z(z),
        iv_vx(vx * DAYS_PER_YEAR), iv_vy(vy * DAYS_PER_YEAR), iv_vz(vz * DAYS_PER_YEAR),
        iv_mass(mass * SOLAR_MASS) {}
  const char* rb_class_name() const override { return "Planet"; }
};

// Tracer: Planet holds only doubles — empty FieldList. Only compiled under Dustman.
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Planet> : dustman::FieldList<Ruby_Planet> {};
#endif

static inline void move_from_i(gc_ref<Ruby_Planet> self,
                               RubyArray<gc_ref<Ruby_Planet>>& bodies,
                               int64_t nbodies, double dt, int64_t i) {
  while (i < nbodies) {
    gc_ref<Ruby_Planet> b2 = bodies[i];
    double dx = self->iv_x - b2->iv_x;
    double dy = self->iv_y - b2->iv_y;
    double dz = self->iv_z - b2->iv_z;
    double dsq = dx*dx + dy*dy + dz*dz;
    double mag = dt / (dsq * std::sqrt(dsq));
    double b_mm  = self->iv_mass * mag;
    double b2_mm = b2->iv_mass * mag;
    self->iv_vx -= dx * b2_mm;
    self->iv_vy -= dy * b2_mm;
    self->iv_vz -= dz * b2_mm;
    b2->iv_vx += dx * b_mm;
    b2->iv_vy += dy * b_mm;
    b2->iv_vz += dz * b_mm;
    i++;
  }
  self->iv_x += dt * self->iv_vx;
  self->iv_y += dt * self->iv_vy;
  self->iv_z += dt * self->iv_vz;
}

static void offset_momentum(RubyArray<gc_ref<Ruby_Planet>>& bodies) {
  double px = 0.0, py = 0.0, pz = 0.0;
  for (int64_t i = 0; i < bodies.len(); i++) {
    gc_ref<Ruby_Planet> b = bodies[i];
    double m = b->iv_mass;
    px += b->iv_vx * m;
    py += b->iv_vy * m;
    pz += b->iv_vz * m;
  }
  gc_ref<Ruby_Planet> b0 = bodies[0];
  b0->iv_vx = -px / SOLAR_MASS;
  b0->iv_vy = -py / SOLAR_MASS;
  b0->iv_vz = -pz / SOLAR_MASS;
}

int main() {
  FROZONE_GC_INIT();
  double last_x = 0.0;

  for (int64_t rep = 0; rep < 100; rep++) {
    RubyArray<gc_ref<Ruby_Planet>> bodies(5);
    bodies[0] = gc_new<Ruby_Planet>(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
    bodies[1] = gc_new<Ruby_Planet>(4.841431442464721, -1.1603200440274284, -0.10362204447112311, 0.001660076642744037, 0.007699011184197404, -6.90460016972063e-05, 0.0009547919384243266);
    bodies[2] = gc_new<Ruby_Planet>(8.34336671824458, 4.124798564124305, -0.4035234171143214, -0.002767425107268624, 0.004998528012349172, 2.3041729757376393e-05, 0.0002858859806661308);
    bodies[3] = gc_new<Ruby_Planet>(12.894369562139131, -15.111151401698631, -0.22330757889265573, 0.002964601375647616, 0.0023784717395948095, -2.9658956854023756e-05, 4.366244043351563e-05);
    bodies[4] = gc_new<Ruby_Planet>(15.379697114850917, -25.919314609987964, 0.17925877295037118, 0.0026806777249038932, 0.001628241700382423, -9.515922545197159e-05, 5.1513890204661145e-05);

    offset_momentum(bodies);

    for (int64_t s = 0; s < N; s++) {
      for (int64_t i = 0; i < NBODIES; i++) {
        move_from_i(bodies[i], bodies, NBODIES, DT, i + 1);
      }
    }

    last_x = bodies[0]->iv_x;
  }

  ruby_puts(last_x);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
