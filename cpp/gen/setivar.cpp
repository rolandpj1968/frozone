#include "../runtime/frozone.hpp"


struct Ruby_TheClass : public RubyObject {
  int64_t iv_v0 = 0;
  int64_t iv_v1 = 0;
  int64_t iv_v3 = 0;
  int64_t iv_levar = 0;

  Ruby_TheClass() {
    iv_v0 = INT64_C(1);
    iv_v1 = INT64_C(2);
    iv_v3 = INT64_C(3);
    iv_levar = INT64_C(1);
  }
  const char* rb_class_name() const override { return "TheClass"; }

  auto set_value_loop() {
    int64_t i = 0;
    (i = INT64_C(0));
    while ((i < INT64_C(10000))) {
      iv_levar = i;
      iv_levar = i;
      iv_levar = i;
      iv_levar = i;
      iv_levar = i;
      (i = (i + INT64_C(1)));
    }
    return RubyNil();
  }

};
template<> inline const char* ruby_class_name<Ruby_TheClass>() { return "TheClass"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TheClass> : dustman::FieldList<Ruby_TheClass> {};
#endif





int main() {
  FROZONE_GC_INIT();
  gc_ref<Ruby_TheClass> obj = nullptr;
  std::optional<int64_t> last;
  (obj = gc_new<Ruby_TheClass>());
  (last = ruby_to_opt<int64_t>(INT64_C(0)));
  for (int64_t _i = 0; _i < INT64_C(300); _i++) {
    (last = ruby_to_opt<int64_t>(obj->set_value_loop()));
  }
  ruby_puts(last);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
