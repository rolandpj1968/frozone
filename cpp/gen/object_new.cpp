#include "../runtime/frozone.hpp"





int main() {
  Ruby_Object last;
  int64_t i = 0;
  (last = RUBY_NIL);
  for (int64_t _i = 0; _i < INT64_C(300); _i++) {
    (i = INT64_C(0));
    while ((i < INT64_C(1000))) {
      (last = Ruby_Object());
      (i = (i + INT64_C(1)));
    };
  }
  ruby_puts(ruby_class(last));
  return 0;
}
