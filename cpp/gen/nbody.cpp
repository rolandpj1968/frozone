#include "../runtime/frozone.hpp"

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
