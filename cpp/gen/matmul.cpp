#include "../runtime/frozone.hpp"

static const int64_t N = 200LL;




static auto make_shareable(auto x) {
  return x;
}

static auto matgen(auto n) {
  std::decay_t<decltype(((1.0 / n) / n))> tmp{};
  (tmp = ((1.0 / n) / n));
  return ({ auto _n = n; int64_t i = 0; auto _e0 = ({ auto _n = n; int64_t j = 0; auto _e0 = ((tmp * (i - j)) * (i + j)); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (j = 1; j < _n; j++) { _arr[j] = ((tmp * (i - j)) * (i + j)); } _arr; }); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (i = 1; i < _n; i++) { _arr[i] = ({ auto _n = n; int64_t j = 0; auto _e0 = ((tmp * (i - j)) * (i + j)); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (j = 1; j < _n; j++) { _arr[j] = ((tmp * (i - j)) * (i + j)); } _arr; }); } _arr; });
}

static auto matmul(auto a, auto b) {
  std::decay_t<decltype(a.len())> m{};
  std::decay_t<decltype(a[INT64_C(0)].len())> n{};
  std::decay_t<decltype(b[INT64_C(0)].len())> p{};
  int64_t k = 0;
  std::decay_t<decltype(b[k])> bk{};
  int64_t j = 0;
  (m = a.len());
  (n = a[INT64_C(0)].len());
  (p = b[INT64_C(0)].len());
  auto c = ({ auto _n = m; int64_t _ai = 0; auto _e0 = make_ra(p, 0.0); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (_ai = 1; _ai < _n; _ai++) { _arr[_ai] = make_ra(p, 0.0); } _arr; });
  for (int64_t i = INT64_C(0); i < m; i++) {
    auto ci = c[i];
    auto ai = a[i];
    (k = INT64_C(0));
    while ((k < n)) {
    auto aik = ai[k];
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
  double last = 0.0;
  std::decay_t<decltype(matgen(N))> a{};
  std::decay_t<decltype(matgen(N))> b{};
  std::decay_t<decltype(matmul(a, b))> c{};
  (last = 0.0);
  for (int64_t _i = 0; _i < INT64_C(20); _i++) {
    (a = matgen(N));
    (b = matgen(N));
    (c = matmul(a, b));
    (last = c[(N / INT64_C(2))][(N / INT64_C(2))]);
  }
  ruby_puts(last);
  return 0;
}
