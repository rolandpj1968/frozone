#include "../runtime/frozone.hpp"






int main() {
  int64_t x = 0;
  int64_t result = 0;
  (x = INT64_C(2));
  (result = /* UNSUPPORTED: Case */);
  ruby_puts(result);
  return 0;
}
