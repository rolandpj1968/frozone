#include "../runtime/frozone.hpp"





static std::optional<int64_t> find(auto arr, auto target) {
  int64_t i = 0;
  (i = INT64_C(0));
  while ((i < INT64_C(3))) {
    if ((arr[i] == target)) {
    return arr[i];
  };
    (i = (i + INT64_C(1)));
  }
  return std::nullopt;
}


int main() {
  ruby_puts(find(({ auto _e0 = INT64_C(10); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = INT64_C(20); _a[2] = INT64_C(30); _a; }), INT64_C(20)));
  ruby_puts(ruby_nil_q(find(({ auto _e0 = INT64_C(10); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = INT64_C(20); _a[2] = INT64_C(30); _a; }), INT64_C(99))));
  return 0;
}
