#include "../runtime/frozone.hpp"


struct Ruby_TheClass {
  struct Impl {
    int64_t iv_v0 = 0;
    int64_t iv_v1 = 0;
    int64_t iv_v2 = 0;
    int64_t iv_levar = 0;
  };
  std::shared_ptr<Impl> p;

  Ruby_TheClass() = default;
  Ruby_TheClass(const RubyNil&) {}
  Ruby_TheClass(int64_t _v0, int64_t _v1, int64_t _v2, int64_t _levar) : p(std::make_shared<Impl>()) {
    p->iv_v0 = _v0;
    p->iv_v1 = _v1;
    p->iv_v2 = _v2;
    p->iv_levar = _levar;
  }

  int64_t v0() const { return p->iv_v0; }
  void set_v0(int64_t v) { p->iv_v0 = v; }
  int64_t v1() const { return p->iv_v1; }
  void set_v1(int64_t v) { p->iv_v1 = v; }
  int64_t v2() const { return p->iv_v2; }
  void set_v2(int64_t v) { p->iv_v2 = v; }
  int64_t levar() const { return p->iv_levar; }
  void set_levar(int64_t v) { p->iv_levar = v; }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_TheClass>() { return "TheClass"; }



static auto set_value_loop(auto obj) {
  int64_t i = 0;
  (i = INT64_C(0));
  while ((i < INT64_C(1000000))) {
    obj.set_levar(i);
    obj.set_levar(i);
    obj.set_levar(i);
    obj.set_levar(i);
    obj.set_levar(i);
    obj.set_levar(i);
    obj.set_levar(i);
    obj.set_levar(i);
    obj.set_levar(i);
    obj.set_levar(i);
    (i = (i + INT64_C(1)));
  }
  return RubyNil();
}


int main() {
  Ruby_TheClass obj;
  (obj = Ruby_TheClass(INT64_C(1), INT64_C(2), INT64_C(3), INT64_C(1)));
  for (int64_t _i = 0; _i < INT64_C(850); _i++) {
    set_value_loop(obj);
  }
  ruby_puts(obj.levar());
  return 0;
}
