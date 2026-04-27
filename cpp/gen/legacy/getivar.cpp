#include "../../runtime/frozone.hpp"


struct Ruby_TheClass : public RubyObject {
  int64_t iv_levar = 0;

  Ruby_TheClass() {
    INT64_C(1);
    INT64_C(2);
    INT64_C(3);
    iv_levar = INT64_C(1);
  }
  const char* rb_class_name() const override { return "TheClass"; }

  auto get_value_loop() {
    int64_t sum = 0;
    int64_t i = 0;
    (sum = INT64_C(0));
    (i = INT64_C(0));
    while ((i < INT64_C(10000))) {
      (sum = (sum + iv_levar));
      (sum = (sum + iv_levar));
      (sum = (sum + iv_levar));
      (sum = (sum + iv_levar));
      (sum = (sum + iv_levar));
      (i = (i + INT64_C(1)));
    }
    return sum;
  }

};
template<> inline const char* ruby_class_name<Ruby_TheClass>() { return "TheClass"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TheClass> : dustman::FieldList<Ruby_TheClass> {};
#endif


static Ruby_TheClass OBJ;



int main() {
  FROZONE_GC_INIT();
  int64_t last = 0;
  (last = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(300); _i++) {
    (last = OBJ.get_value_loop());
  }
  ruby_puts(last);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
