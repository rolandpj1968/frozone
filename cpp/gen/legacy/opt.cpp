#include "../runtime/frozone.hpp"





static auto find(auto arr, auto x) {
  int64_t i = 0;
  (i = INT64_C(0));
  while ((i < arr.len())) {
    if ((arr[i] == x)) {
    return i;
  };
    (i = (i + INT64_C(1)));
  }
  return std::optional<int64_t>(RUBY_NIL);
}


int main() {
  FROZONE_GC_INIT();
  ruby_puts(find(({ auto _e0 = INT64_C(10); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = INT64_C(20); _a[2] = INT64_C(30); _a; }), INT64_C(20)));
  ruby_puts(ruby_class(find(({ auto _e0 = INT64_C(10); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = INT64_C(20); _a[2] = INT64_C(30); _a; }), INT64_C(99))));
  FROZONE_GC_SHUTDOWN();
  return 0;
}
