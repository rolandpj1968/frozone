#include "../runtime/frozone.hpp"


struct Ruby_TheClass : public RubyObject {
  int64_t iv_v0 = 0;
  int64_t iv_v1 = 0;
  int64_t iv_v2 = 0;
  int64_t iv_levar = 0;

  Ruby_TheClass() = default;
  Ruby_TheClass(auto _v0, auto _v1, auto _v2, auto _levar) {
    iv_v0 = _v0;
    iv_v1 = _v1;
    iv_v2 = _v2;
    iv_levar = _levar;
  }
  const char* rb_class_name() const override { return "TheClass"; }

  auto v0() const { return iv_v0; }
  void set_v0(auto v) { iv_v0 = v; }
  auto v1() const { return iv_v1; }
  void set_v1(auto v) { iv_v1 = v; }
  auto v2() const { return iv_v2; }
  void set_v2(auto v) { iv_v2 = v; }
  auto levar() const { return iv_levar; }
  void set_levar(auto v) { iv_levar = v; }

};
template<> inline const char* ruby_class_name<Ruby_TheClass>() { return "TheClass"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TheClass> : dustman::FieldList<Ruby_TheClass> {};
#endif




static auto set_value_loop(auto obj) {
  int64_t i = 0;
  (i = INT64_C(0));
  while ((i < INT64_C(1000000))) {
    obj->set_levar(i);
    obj->set_levar(i);
    obj->set_levar(i);
    obj->set_levar(i);
    obj->set_levar(i);
    obj->set_levar(i);
    obj->set_levar(i);
    obj->set_levar(i);
    obj->set_levar(i);
    obj->set_levar(i);
    (i = (i + INT64_C(1)));
  }
  return RubyNil();
}


int main() {
  FROZONE_GC_INIT();
  gc_ref<Ruby_TheClass> obj = nullptr;
  (obj = gc_new<Ruby_TheClass>(INT64_C(1), INT64_C(2), INT64_C(3), INT64_C(1)));
  for (int64_t _i = 0; _i < INT64_C(850); _i++) {
    set_value_loop(obj);
  }
  ruby_puts(obj->levar());
  FROZONE_GC_SHUTDOWN();
  return 0;
}
