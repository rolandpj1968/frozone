#include "../runtime/frozone.hpp"


struct Ruby_C : public RubyObject {
  int64_t iv_a = 0;
  int64_t iv_b = 0;
  int64_t iv_c = 0;
  int64_t iv_d = 0;

  Ruby_C() = default;
  Ruby_C(auto a, auto b, auto c, auto d) {
    iv_a = a;
    iv_b = b;
    iv_c = c;
    iv_d = d;
  }
  const char* rb_class_name() const override { return "C"; }

};
template<> inline const char* ruby_class_name<Ruby_C>() { return "C"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_C> : dustman::FieldList<Ruby_C> {};
#endif




static auto test() {
  return gc_new<Ruby_C>(INT64_C(1), INT64_C(2), INT64_C(3), INT64_C(4));
}


int main() {
  FROZONE_GC_INIT();
  gc_ref<Ruby_C> last = nullptr;
  int64_t i = 0;
  (last = nullptr);
  for (int64_t _i = 0; _i < INT64_C(300); _i++) {
    (i = INT64_C(0));
    while ((i < INT64_C(1000))) {
      (last = test());
      (i = (i + INT64_C(1)));
    };
  }
  ruby_puts(ruby_class(last));
  FROZONE_GC_SHUTDOWN();
  return 0;
}
