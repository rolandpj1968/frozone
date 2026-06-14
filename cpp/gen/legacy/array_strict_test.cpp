#include "../../runtime/frozone.hpp"






int main() {
  FROZONE_GC_INIT();
  RubyArray<int64_t> a;
  (a = ({ auto _e0 = INT64_C(10); auto _a = RubyArray<decltype(_e0)>(5); _a[0] = _e0; _a[1] = INT64_C(20); _a[2] = INT64_C(30); _a[3] = INT64_C(40); _a[4] = INT64_C(50); _a; }));
  ruby_puts(a[INT64_C(0)]);
  ruby_puts(a[INT64_C(2)]);
  ruby_puts(a[INT64_C(-1)]);
  ruby_puts(a[INT64_C(10)].inspect());
  ruby_puts(a[INT64_C(-10)].inspect());
  ruby_puts(a.slice(INT64_C(1), INT64_C(2)).join(RubyString(",", 1)));
  ruby_puts(a.slice(INT64_C(-2), INT64_C(2)).join(RubyString(",", 1)));
  ruby_puts(a.slice(INT64_C(3), INT64_C(10)).join(RubyString(",", 1)));
  ruby_puts(a.slice(INT64_C(10), INT64_C(2)).inspect());
  ruby_puts(a[(INT64_C(3) + 1LL)].join(RubyString(",", 1)));
  ruby_puts(a[INT64_C(3)].join(RubyString(",", 1)));
  ruby_puts(a[(INT64_C(-2) + 1LL)].join(RubyString(",", 1)));
  ruby_puts(a[(/* UNSUPPORTED: NilClass */ + 1LL)].join(RubyString(",", 1)));
  ruby_puts(a[(INT64_C(2) + 1LL)].join(RubyString(",", 1)));
  ruby_puts(a[(RUBY_NIL + 1LL)].join(RubyString(",", 1)));
  try {
    a.operator[](INT64_C(1), INT64_C(2), INT64_C(3));
  } catch (Ruby_ArgumentError&) {
    ruby_puts(RubyString("ArgumentError 3-arg", 19));
  }
  try {
    a[RubyString("x", 1)];
  } catch (Ruby_TypeError&) {
    ruby_puts(RubyString("TypeError non-Integer", 21));
  }
  FROZONE_GC_SHUTDOWN();
  return 0;
}
