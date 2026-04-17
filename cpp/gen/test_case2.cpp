#include "../runtime/frozone.hpp"






int main() {
  int64_t x = 0;
  RubyString result;
  (x = INT64_C(2));
  (result = ({ auto _cs = x; ((_cs == INT64_C(1))) ? (RubyString("one", 3)) : (((_cs == INT64_C(2))) ? (RubyString("two", 3)) : (((_cs == INT64_C(3))) ? (RubyString("three", 5)) : (RubyString("other", 5)))); }));
  ruby_puts(result);
  return 0;
}
