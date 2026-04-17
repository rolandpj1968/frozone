#include "../runtime/frozone.hpp"





static auto nq_solve(auto n) {
  std::decay_t<decltype(make_ra(n, INT64_C(-1)))> a{};
  std::decay_t<decltype(make_ra(n, INT64_C(0)))> l{};
  std::decay_t<decltype(make_ra(n, INT64_C(0)))> c{};
  std::decay_t<decltype(make_ra(n, INT64_C(0)))> r{};
  std::decay_t<decltype(((INT64_C(1) << n) - INT64_C(1)))> y0{};
  int64_t m = 0;
  int64_t k = 0;
  std::decay_t<decltype((((l[k] | c[k]) | r[k]) & y0))> y{};
  std::decay_t<decltype((a[k] + INT64_C(1)))> i{};
  std::decay_t<decltype((INT64_C(1) << i))> z{};
  (a = make_ra(n, INT64_C(-1)));
  (l = make_ra(n, INT64_C(0)));
  (c = make_ra(n, INT64_C(0)));
  (r = make_ra(n, INT64_C(0)));
  (y0 = ((INT64_C(1) << n) - INT64_C(1)));
  (m = INT64_C(0));
  (k = INT64_C(0));
  while ((k >= INT64_C(0))) {
    (y = (((l[k] | c[k]) | r[k]) & y0));
    if ((((y ^ y0) >> (a[k] + INT64_C(1))) != INT64_C(0))) {
    (i = (a[k] + INT64_C(1)));
    while (({ auto _l = ((i < n)); (_l) ? decltype((((y & (INT64_C(1) << i)) != INT64_C(0))))(((y & (INT64_C(1) << i)) != INT64_C(0))) : decltype((((y & (INT64_C(1) << i)) != INT64_C(0))))(_l); })) {
    (i = (i + INT64_C(1)));
  };
    if ((k < (n - INT64_C(1)))) {
    (z = (INT64_C(1) << i));
    a[k] = i;
    (k = (k + INT64_C(1)));
    l[k] = ((l[(k - INT64_C(1))] | z) << INT64_C(1));
    c[k] = (c[(k - INT64_C(1))] | z);
    r[k] = ((r[(k - INT64_C(1))] | z) >> INT64_C(1));
  } else {
    (m = (m + INT64_C(1)));
    (k = (k - INT64_C(1)));
  };
  } else {
    a[k] = INT64_C(-1);
    (k = (k - INT64_C(1)));
  };
  }
  return m;
}


int main() {
  int64_t last = 0;
  (last = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(500); _i++) {
    (last = nq_solve(INT64_C(12)));
  }
  ruby_puts(last);
  return 0;
}
