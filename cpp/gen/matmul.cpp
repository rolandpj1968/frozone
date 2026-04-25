#include "../runtime/frozone.hpp"

static const int64_t N = 200LL;




static RubyObject* make_shareable(auto x) {
  std::fprintf(stderr, "frozone: called TI-gap stub make_shareable\n"); std::abort();
  return nullptr;
}

static RubyArray<RubyArray<double>> matgen(auto n) {
  double tmp = 0.0;
  (tmp = ruby_div(ruby_div(1.0, n), n));
  return ({ auto _n = n; int64_t i = 0; auto _e0 = ({ auto _n = n; int64_t j = 0; auto _e0 = ((tmp * (i - j)) * (i + j)); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (j = 1; j < _n; j++) { _arr[j] = ((tmp * (i - j)) * (i + j)); } _arr; }); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (i = 1; i < _n; i++) { _arr[i] = ({ auto _n = n; int64_t j = 0; auto _e0 = ((tmp * (i - j)) * (i + j)); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (j = 1; j < _n; j++) { _arr[j] = ((tmp * (i - j)) * (i + j)); } _arr; }); } _arr; });
}

static RubyArray<RubyArray<double>> matmul(auto a, auto b) {
  int64_t m = 0;
  int64_t n = 0;
  int64_t p = 0;
  RubyArray<RubyArray<double>> c;
  RubyArray<double> ci;
  RubyArray<double> ai;
  int64_t k = 0;
  double aik = 0.0;
  RubyArray<double> bk;
  int64_t j = 0;
  (m = a.len());
  (n = a[INT64_C(0)].len());
  (p = b[INT64_C(0)].len());
  (c = ({ auto _n = m; int64_t _ai = 0; auto _e0 = make_ra(p, 0.0); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (_ai = 1; _ai < _n; _ai++) { _arr[_ai] = make_ra(p, 0.0); } _arr; }));
  for (int64_t i = INT64_C(0); i < m; i++) {
    (ci = c[i]);
    (ai = a[i]);
    (k = INT64_C(0));
    while ((k < n)) {
    (aik = ai[k]);
    (bk = b[k]);
    (j = INT64_C(0));
    while ((j < p)) {
    ci[j] += (aik * bk[j]);
    (j = (j + INT64_C(1)));
  };
    (k = (k + INT64_C(1)));
  };
  }
  return c;
}


int main() {
  FROZONE_GC_INIT();
  double last = 0.0;
  RubyArray<RubyArray<double>> a;
  RubyArray<RubyArray<double>> b;
  RubyArray<RubyArray<double>> c;
  (last = 0.0);
  for (int64_t _i = 0; _i < INT64_C(20); _i++) {
    (a = matgen(N));
    (b = matgen(N));
    (c = matmul(a, b));
    (last = c[ruby_div(N, INT64_C(2))][ruby_div(N, INT64_C(2))]);
  }
  ruby_puts(last);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
