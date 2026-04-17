#include "../runtime/frozone.hpp"

static const int64_t U = 5LL;
static const int64_t R = 7LL;





int main() {
  std::decay_t<decltype(U)> u{};
  std::decay_t<decltype(R)> r{};
  std::decay_t<decltype(make_ra(INT64_C(10000), INT64_C(0)))> a{};
  int64_t last = 0;
  (u = U);
  (r = R);
  (a = make_ra(INT64_C(10000), INT64_C(0)));
  for (int64_t i = 0; i < INT64_C(4000); i++) {
    for (int64_t j = 0; j < INT64_C(4000); j++) {
      a[i] += ruby_mod(j, u);
    };
    a[i] += r;
  }
  if (!((a[INT64_C(7)] == INT64_C(8007)))) {
    throw Ruby_RuntimeError();
  }
  (last = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(10); _i++) {
    (u = U);
    (r = R);
    (a = make_ra(INT64_C(10000), INT64_C(0)));
    for (int64_t i = 0; i < INT64_C(4000); i++) {
      for (int64_t j = 0; j < INT64_C(4000); j++) {
        a[i] += ruby_mod(j, u);
      };
      a[i] += r;
    };
    (last = a[INT64_C(7)]);
  }
  ruby_puts(last);
  return 0;
}
