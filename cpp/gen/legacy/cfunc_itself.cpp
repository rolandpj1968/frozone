#include "../../runtime/frozone.hpp"






int main() {
  FROZONE_GC_INIT();
  int64_t count = 0;
  (count = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(500); _i++) {
    for (int64_t i = 0; i < INT64_C(500000); i++) {
      0LL;
      0LL;
      0LL;
      0LL;
      0LL;
      0LL;
      0LL;
      0LL;
      0LL;
      0LL;
      (count = (count + INT64_C(1)));
    };
  }
  ruby_puts(count);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
