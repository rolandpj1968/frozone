#include "../runtime/frozone.hpp"





static auto nq_solve(auto n) {
  RubyArray<int64_t> a;
  RubyArray<int64_t> l;
  RubyArray<int64_t> c;
  RubyArray<int64_t> r;
  int64_t y0 = 0;
  int64_t m = 0;
  int64_t k = 0;
  int64_t y = 0;
  int64_t i = 0;
  int64_t z = 0;
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
  FROZONE_GC_INIT();
  int64_t last = 0;
  (last = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(3); _i++) {
    (last = nq_solve(INT64_C(8)));
  }
  ruby_puts(last);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
