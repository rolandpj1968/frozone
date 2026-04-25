#include "../runtime/frozone.hpp"

static const int64_t N = 9LL;




static RubyArray<int64_t> fannkuch(auto n) {
  RubyArray<int64_t> p;
  RubyArray<int64_t> s;
  RubyArray<int64_t> q;
  int64_t sign = 0;
  int64_t sum = 0;
  int64_t maxflips = 0;
  int64_t q1 = 0;
  int64_t flips = 0;
  int64_t qq = 0;
  int64_t i = 0;
  int64_t j = 0;
  std::decay_t<decltype(p.delete_at(INT64_C(1)))> t{};
  (p = ruby_range_to_a(INT64_C(0), n, false));
  (s = p.dup_());
  (q = p.dup_());
  (sign = INT64_C(1));
  (sum = (maxflips = INT64_C(0)));
  while (true) {
    if (((q1 = p[INT64_C(1)]) != INT64_C(1))) {
    q.slice_assign(INT64_C(0), INT64_C(-1), p);
    (flips = INT64_C(1));
    while (!(((qq = q[q1]) == INT64_C(1)))) {
    q[q1] = q1;
    if ((q1 >= INT64_C(4))) {
    auto _t1_0 = INT64_C(2);
    auto _t1_1 = (q1 - INT64_C(1));
    i = _t1_0;
    j = _t1_1;
    while ((i < j)) {
    auto _t2_0 = q[j];
    auto _t2_1 = q[i];
    q[i] = _t2_0;
    q[j] = _t2_1;
    (i = (i + INT64_C(1)));
    (j = (j - INT64_C(1)));
  };
  };
    (q1 = qq);
    (flips = (flips + INT64_C(1)));
  };
    (sum = (sum + (sign * flips)));
    if ((flips > maxflips)) {
    (maxflips = flips);
  };
  };
    if ((sign == INT64_C(1))) {
    auto _t3_0 = p[INT64_C(2)];
    auto _t3_1 = p[INT64_C(1)];
    p[INT64_C(1)] = _t3_0;
    p[INT64_C(2)] = _t3_1;
    (sign = INT64_C(-1));
  } else {
    auto _t4_0 = p[INT64_C(3)];
    auto _t4_1 = p[INT64_C(2)];
    p[INT64_C(2)] = _t4_0;
    p[INT64_C(3)] = _t4_1;
    (sign = INT64_C(1));
    (i = INT64_C(3));
    while (({ auto _l = ((i <= n)); (_l) ? decltype(((s[i] == INT64_C(1))))((s[i] == INT64_C(1))) : decltype(((s[i] == INT64_C(1))))(_l); })) {
    if ((i == n)) {
    return ({ auto _e0 = sum; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = maxflips; _a; });
  };
    s[i] = i;
    (t = p.delete_at(INT64_C(1)));
    (i = (i + INT64_C(1)));
    p.insert(i, t);
  };
    if ((i <= n)) {
    s[i] -= INT64_C(1);
  };
  };
  }
  return RubyArray<int64_t>(RUBY_NIL);
}


int main() {
  FROZONE_GC_INIT();
  int64_t sum = 0;
  int64_t flips = 0;
  (sum = INT64_C(0));
  (flips = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(10); _i++) {
    ({ auto _masgn = fannkuch(N); sum = _masgn[INT64_C(0)]; flips = _masgn[INT64_C(1)]; });
  }
  ruby_puts(sum);
  ruby_puts(flips);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
