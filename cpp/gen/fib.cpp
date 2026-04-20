#include "../runtime/frozone.hpp"





static auto fib(auto n) {
  if ((n < INT64_C(2))) {
    return n;
  }
  return (fib((n - INT64_C(1))) + fib((n - INT64_C(2))));
}


int main() {
  FROZONE_GC_INIT();
  int64_t total = 0;
  (total = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(3); _i++) {
    (total = (total + fib(INT64_C(35))));
  }
  ruby_puts(total);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
