#include "../runtime/frozone.hpp"





static auto add(auto left, auto right) {
  return (left + right);
}


int main() {
  FROZONE_GC_INIT();
  int64_t last = 0;
  (last = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(3); _i++) {
    for (int64_t i = 0; i < INT64_C(5000); i++) {
      add(INT64_C(1), INT64_C(0));
      add(INT64_C(1), INT64_C(1));
      add(INT64_C(1), INT64_C(2));
      add(INT64_C(1), INT64_C(3));
      (last = add(INT64_C(1), INT64_C(4)));
    };
  }
  ruby_puts(last);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
