#include "../runtime/frozone.hpp"

static const double SOLAR_MASS = 39.47841760435743;
static const double DAYS_PER_YEAR = 365.24;
static const int64_t N = 20000LL;
static const int64_t NBODIES = 5LL;
static const double DT = 0.01;

struct Ruby_Planet : public RubyObject {
  double iv_x = 0.0;
  double iv_y = 0.0;
  double iv_z = 0.0;
  double iv_vx = 0.0;
  double iv_vy = 0.0;
  double iv_vz = 0.0;
  double iv_mass = 0.0;

  Ruby_Planet() = default;
  Ruby_Planet(auto x, auto y, auto z, auto vx, auto vy, auto vz, auto mass) {
    auto _t1_0 = x;
    auto _t1_1 = y;
    auto _t1_2 = z;
    iv_x = _t1_0;
    iv_y = _t1_1;
    iv_z = _t1_2;
    auto _t2_0 = (vx * DAYS_PER_YEAR);
    auto _t2_1 = (vy * DAYS_PER_YEAR);
    auto _t2_2 = (vz * DAYS_PER_YEAR);
    iv_vx = _t2_0;
    iv_vy = _t2_1;
    iv_vz = _t2_2;
    iv_mass = (mass * SOLAR_MASS);
  }
  const char* rb_class_name() const override { return "Planet"; }

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
    gc_local<Ruby_Planet> b2 = nullptr;
    double dx = 0.0;
    double dy = 0.0;
    double dz = 0.0;
    double dsq = 0.0;
    double mag = 0.0;
    double b_mass_mag = 0.0;
    double b2_mass_mag = 0.0;
    while ((i < nbodies)) {
      (b2 = bodies[i]);
      (dx = (iv_x - b2->x()));
      (dy = (iv_y - b2->y()));
      (dz = (iv_z - b2->z()));
      (dsq = (((dx * dx) + (dy * dy)) + (dz * dz)));
      (mag = ruby_div(dt, (dsq * sqrt(dsq))));
      auto _t3_0 = (iv_mass * mag);
      auto _t3_1 = (b2->mass() * mag);
      b_mass_mag = _t3_0;
      b2_mass_mag = _t3_1;
      iv_vx = (iv_vx - (dx * b2_mass_mag));
      iv_vy = (iv_vy - (dy * b2_mass_mag));
      iv_vz = (iv_vz - (dz * b2_mass_mag));
      b2->add_v((dx * b_mass_mag), (dy * b_mass_mag), (dz * b_mass_mag));
      (i = (i + INT64_C(1)));
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

};
template<> inline const char* ruby_class_name<Ruby_Planet>() { return "Planet"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Planet> : dustman::FieldList<Ruby_Planet> {};
#endif




static auto energy(auto bodies) {
  double e = 0.0;
  std::decay_t<decltype(bodies.len())> nbodies{};
  double distance = 0.0;
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
    (distance = sqrt((((dx * dx) + (dy * dy)) + (dz * dz))));
    (e = (e - ruby_div((b.mass() * b2.mass()), distance)));
  };
  }
  return e;
}

static auto offset_momentum(auto bodies) {
  double px = 0.0;
  double py = 0.0;
  double pz = 0.0;
  double m = 0.0;
  gc_local<Ruby_Planet> b = nullptr;
  auto _t4_0 = 0.0;
  auto _t4_1 = 0.0;
  auto _t4_2 = 0.0;
  px = _t4_0;
  py = _t4_1;
  pz = _t4_2;
  for (int64_t _fi = 0; _fi < (bodies).len(); _fi++) {
    b = (bodies)[_fi];
    (m = b->mass());
    (px = (px + (b->vx() * m)));
    (py = (py + (b->vy() * m)));
    (pz = (pz + (b->vz() * m)));
  }
  (b = bodies[INT64_C(0)]);
  b->set_vx(ruby_div((-(px)), SOLAR_MASS));
  b->set_vy(ruby_div((-(py)), SOLAR_MASS));
  return b->set_vz(ruby_div((-(pz)), SOLAR_MASS));
}


int main() {
  FROZONE_GC_INIT();
  double last_x = 0.0;
  int64_t nbodies = 0;
  int64_t n = 0;
  double dt = 0.0;
  RubyArray<gc_ref<Ruby_Planet>> bodies;
  int64_t i = 0;
  gc_local<Ruby_Planet> b = nullptr;
  (last_x = 0.0);
  for (int64_t _i = 0; _i < INT64_C(100); _i++) {
    (nbodies = NBODIES);
    (n = N);
    (dt = DT);
    (bodies = ({ auto _e0 = gc_new<Ruby_Planet>(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0); auto _a = RubyArray<decltype(_e0)>(5); _a[0] = _e0; _a[1] = gc_new<Ruby_Planet>(4.841431442464721, -1.1603200440274284, -0.10362204447112311, 0.001660076642744037, 0.007699011184197404, -6.90460016972063e-05, 0.0009547919384243266); _a[2] = gc_new<Ruby_Planet>(8.34336671824458, 4.124798564124305, -0.4035234171143214, -0.002767425107268624, 0.004998528012349172, 2.3041729757376393e-05, 0.0002858859806661308); _a[3] = gc_new<Ruby_Planet>(12.894369562139131, -15.111151401698631, -0.22330757889265573, 0.002964601375647616, 0.0023784717395948095, -2.9658956854023756e-05, 4.366244043351563e-05); _a[4] = gc_new<Ruby_Planet>(15.379697114850917, -25.919314609987964, 0.17925877295037118, 0.0026806777249038932, 0.001628241700382423, -9.515922545197159e-05, 5.1513890204661145e-05); _a; }));
    offset_momentum(bodies);
    for (int64_t _i = 0; _i < n; _i++) {
      (i = INT64_C(0));
      while ((i < nbodies)) {
        (b = bodies[i]);
        b->move_from_i(bodies, nbodies, dt, (i + INT64_C(1)));
        (i = (i + INT64_C(1)));
      };
    };
    (last_x = bodies[INT64_C(0)]->x());
  }
  ruby_puts(last_x);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
