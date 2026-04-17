#include "../runtime/frozone.hpp"





static auto test_case(auto x) {
  if ((x == INT64_C(1))) {
    return RubyString("one", 3);
  } else if ((x == INT64_C(2))) {
    return RubyString("two", 3);
  } else if ((x == INT64_C(3))) {
    return RubyString("three", 5);
  } else {
    return RubyString("other", 5);
  }
}


int main() {
  ruby_puts(test_case(INT64_C(2)));
  ruby_puts(test_case(INT64_C(5)));
  return 0;
}
