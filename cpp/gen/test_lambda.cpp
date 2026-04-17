#include "../runtime/frozone.hpp"





static auto test_lambda() {
  auto square = [&](auto x) { return (x * x); };
  return ruby_puts(square(INT64_C(5)));
}


int main() {
  test_lambda();
  return 0;
}
