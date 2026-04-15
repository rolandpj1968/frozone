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
  Ruby_TheClass(auto v0, auto v1, auto v2, auto levar) : p(std::make_shared<Impl>()) {
    p->iv_v0 = v0;
    p->iv_v1 = v1;
    p->iv_v2 = v2;
    p->iv_levar = levar;
  }

  auto v0() {
    return p->iv_v0;
  }

  auto set_v0(auto __anon_req__) {
    p->iv_v0 = __anon_req__;
    return p->iv_v0;
  }

  auto v1() {
    return p->iv_v1;
  }

  auto set_v1(auto __anon_req__) {
    p->iv_v1 = __anon_req__;
    return p->iv_v1;
  }

  auto v2() {
    return p->iv_v2;
  }

  auto set_v2(auto __anon_req__) {
    p->iv_v2 = __anon_req__;
    return p->iv_v2;
  }

  auto levar() {
    return p->iv_levar;
  }

  auto set_levar(auto __anon_req__) {
    p->iv_levar = __anon_req__;
    return p->iv_levar;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_TheClass>() { return "TheClass"; }



static auto get_value_loop(auto obj) {
  int64_t sum = 0;
  int64_t i = 0;
  (sum = INT64_C(0));
  (i = INT64_C(0));
  while ((i < INT64_C(1000000))) {
    (sum = (sum + obj.levar()));
    (sum = (sum + obj.levar()));
    (sum = (sum + obj.levar()));
    (sum = (sum + obj.levar()));
    (sum = (sum + obj.levar()));
    (sum = (sum + obj.levar()));
    (sum = (sum + obj.levar()));
    (sum = (sum + obj.levar()));
    (sum = (sum + obj.levar()));
    (sum = (sum + obj.levar()));
    (i = (i + INT64_C(1)));
  }
  return sum;
}


int main() {
  Ruby_TheClass obj;
  int64_t last = 0;
  (obj = Ruby_TheClass(INT64_C(1), INT64_C(2), INT64_C(3), INT64_C(1)));
  (last = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(850); _i++) {
    (last = get_value_loop(obj));
  }
  ruby_puts(last);
  return 0;
}
