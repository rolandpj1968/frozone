#include "../runtime/frozone.hpp"




struct Ruby_MathHelper {
  auto double(auto x) {
    return (x * INT64_C(2));
  }

};
static Ruby_MathHelper MathHelper;



int main() {
  ruby_puts(MathHelper.double(INT64_C(21)));
  return 0;
}
