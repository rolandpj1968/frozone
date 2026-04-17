#include "../runtime/frozone.hpp"





static auto test_rescue() {
  std::decay_t<decltype(ruby_div(INT64_C(1), INT64_C(0)))> x{};
  try {
    (x = ruby_div(INT64_C(1), INT64_C(0)));
  } catch (Ruby_ZeroDivisionError&) {
    ruby_puts(RubyString("caught", 6));
  }
}


int main() {
  test_rescue();
  return 0;
}
