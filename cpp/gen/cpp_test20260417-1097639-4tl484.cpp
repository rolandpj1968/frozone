#include "../runtime/frozone.hpp"






int main() {
  auto square = lambda();
  ruby_puts(square.call(INT64_C(5)));
  return 0;
}
