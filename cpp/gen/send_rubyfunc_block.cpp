#include "../runtime/frozone.hpp"


struct Ruby_C : public RubyObject {

  Ruby_C() {
    RUBY_NIL;
  }
  const char* rb_class_name() const override { return "C"; }

  auto ruby_func() {
    return RubyNil(RUBY_NIL);
  }

};
template<> inline const char* ruby_class_name<Ruby_C>() { return "C"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_C> : dustman::FieldList<Ruby_C> {};
#endif


static Ruby_C INSTANCE;



int main() {
  FROZONE_GC_INIT();
  gc_local<Ruby_C> instance = nullptr;
  int64_t count = 0;
  (instance = gc_new<Ruby_C>());
  (count = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(500); _i++) {
    for (int64_t i = 0; i < INT64_C(500000); i++) {
      instance->ruby_func();
      instance->ruby_func();
      instance->ruby_func();
      instance->ruby_func();
      instance->ruby_func();
      instance->ruby_func();
      instance->ruby_func();
      instance->ruby_func();
      instance->ruby_func();
      (count = (count + INT64_C(1)));
    };
  }
  ruby_puts(count);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
