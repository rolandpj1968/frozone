#include "../../runtime/frozone.hpp"


struct Ruby_A : public RubyObject {

  Ruby_A() {
    RUBY_NIL;
  }
  const char* rb_class_name() const override { return "A"; }

  auto foo() {
    return RubyNil(RUBY_NIL);
  }

  auto foo2() {
    return RubyNil(RUBY_NIL);
  }

};
template<> inline const char* ruby_class_name<Ruby_A>() { return "A"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_A> : dustman::FieldList<Ruby_A> {};
#endif

struct Ruby_B : public Ruby_A {

  Ruby_B() = default;
  const char* rb_class_name() const override { return "B"; }

};
template<> inline const char* ruby_class_name<Ruby_B>() { return "B"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_B> : dustman::FieldList<Ruby_B> {};
#endif

struct Ruby_C : public Ruby_A {

  Ruby_C() = default;
  const char* rb_class_name() const override { return "C"; }

};
template<> inline const char* ruby_class_name<Ruby_C>() { return "C"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_C> : dustman::FieldList<Ruby_C> {};
#endif





int main() {
  FROZONE_GC_INIT();
  gc_local<Ruby_A> a = nullptr;
  gc_local<Ruby_B> b = nullptr;
  gc_local<Ruby_C> c = nullptr;
  bool last = false;
  (a = gc_new<Ruby_A>());
  (b = gc_new<Ruby_B>());
  (c = gc_new<Ruby_C>());
  (last = false);
  for (int64_t _i = 0; _i < INT64_C(1000); _i++) {
    for (int64_t i = 0; i < INT64_C(500000); i++) {
      true;
      true;
      false;
      false;
      true;
      true;
      false;
      false;
      true;
      true;
      false;
      (last = false);
    };
  }
  ruby_puts(last);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
