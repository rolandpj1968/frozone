#include "../../runtime/frozone.hpp"






int main() {
  FROZONE_GC_INIT();
  gc_local<RubyObject> last = nullptr;
  int64_t i = 0;
  (last = nullptr);
  for (int64_t _i = 0; _i < INT64_C(300); _i++) {
    (i = INT64_C(0));
    while ((i < INT64_C(1000))) {
      (last = gc_new<Ruby_Object>());
      (i = (i + INT64_C(1)));
    };
  }
  ruby_puts(ruby_class(last));
  FROZONE_GC_SHUTDOWN();
  return 0;
}
