#include "../runtime/frozone.hpp"






int main() {
  FROZONE_GC_INIT();
  int64_t square = 0;
  (square = [&](auto x) { return (x * x); });
  ruby_puts(square(INT64_C(5)));
  FROZONE_GC_SHUTDOWN();
  return 0;
}
