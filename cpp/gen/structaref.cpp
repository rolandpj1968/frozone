#include "../runtime/frozone.hpp"


struct Ruby_TheClass : public RubyObject {
  int64_t iv_v0 = 0;
  int64_t iv_v1 = 0;
  int64_t iv_v2 = 0;
  int64_t iv_levar = 0;

  Ruby_TheClass() = default;
  Ruby_TheClass(auto v0, auto v1, auto v2, auto levar) {
    iv_v0 = v0;
    iv_v1 = v1;
    iv_v2 = v2;
    iv_levar = levar;
  }
  const char* rb_class_name() const override { return "TheClass"; }

  auto v0() {
    return iv_v0;
  }

  auto set_v0(auto __anon_req__) {
    iv_v0 = __anon_req__;
    return iv_v0;
  }

  auto v1() {
    return iv_v1;
  }

  auto set_v1(auto __anon_req__) {
    iv_v1 = __anon_req__;
    return iv_v1;
  }

  auto v2() {
    return iv_v2;
  }

  auto set_v2(auto __anon_req__) {
    iv_v2 = __anon_req__;
    return iv_v2;
  }

  auto levar() {
    return iv_levar;
  }

  auto set_levar(auto __anon_req__) {
    iv_levar = __anon_req__;
    return iv_levar;
  }

};
template<> inline const char* ruby_class_name<Ruby_TheClass>() { return "TheClass"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_TheClass> : dustman::FieldList<Ruby_TheClass> {};
#endif




static auto get_value_loop(auto obj) {
  int64_t sum = 0;
  int64_t i = 0;
  (sum = INT64_C(0));
  (i = INT64_C(0));
  while ((i < INT64_C(1000000))) {
    (sum = (sum + obj->levar()));
    (sum = (sum + obj->levar()));
    (sum = (sum + obj->levar()));
    (sum = (sum + obj->levar()));
    (sum = (sum + obj->levar()));
    (sum = (sum + obj->levar()));
    (sum = (sum + obj->levar()));
    (sum = (sum + obj->levar()));
    (sum = (sum + obj->levar()));
    (sum = (sum + obj->levar()));
    (i = (i + INT64_C(1)));
  }
  return sum;
}


int main() {
  FROZONE_GC_INIT();
  gc_ref<Ruby_TheClass> obj = nullptr;
  int64_t last = 0;
  (obj = gc_new<Ruby_TheClass>(INT64_C(1), INT64_C(2), INT64_C(3), INT64_C(1)));
  (last = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(850); _i++) {
    (last = get_value_loop(obj));
  }
  ruby_puts(last);
  FROZONE_GC_SHUTDOWN();
  return 0;
}
