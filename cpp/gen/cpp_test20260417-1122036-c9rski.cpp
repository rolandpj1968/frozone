#include "../runtime/frozone.hpp"






int main() {
  int64_t x = 0;
  int64_t result = 0;
  (x = INT64_C(2));
  (result = if ((x == INT64_C(1))) {
    RubyString("one", 3);
  } else if ((x == INT64_C(2))) {
    RubyString("two", 3);
  } else if ((x == INT64_C(3))) {
    RubyString("three", 5);
  } else {
    RubyString("other", 5);
  })
  ruby_puts(result);
  return 0;
}
