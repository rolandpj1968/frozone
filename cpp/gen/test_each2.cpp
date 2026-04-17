#include "../runtime/frozone.hpp"





static auto test_each() {
  { auto _coll = ({ auto _e0 = INT64_C(10); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = INT64_C(20); _a[2] = INT64_C(30); _a; }); for (auto& x : *_coll.data) {
    ruby_puts(x);
  } }
}


int main() {
  test_each();
  return 0;
}
