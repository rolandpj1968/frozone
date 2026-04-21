#include "../runtime/frozone.hpp"






int main() {
  FROZONE_GC_INIT();
  RubyHash<RubySymbol, int64_t> h;
  (h = ({ RubyHash<RubySymbol, gc_ref<RubyObject>> _h; _h.store(ruby_sym("arr"), coerce_to_ref<RubyObject>(({ auto _e0 = INT64_C(1); auto _a = RubyArray<decltype(_e0)>(3); _a[0] = _e0; _a[1] = INT64_C(2); _a[2] = INT64_C(3); _a; }))); _h.store(ruby_sym("str"), coerce_to_ref<RubyObject>(RubyString("hello", 5))); _h; }));
  ruby_puts(ruby_class(h[ruby_sym("arr")]));
  ruby_puts(ruby_class(h[ruby_sym("str")]));
  ruby_puts(h[ruby_sym("arr")].len());
  ruby_puts(h[ruby_sym("str")].len());
  FROZONE_GC_SHUTDOWN();
  return 0;
}
