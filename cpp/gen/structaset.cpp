#include "../runtime/frozone.hpp"


struct Ruby_TheClass {
  struct Impl {
  };
  std::shared_ptr<Impl> p;

  Ruby_TheClass() = default;
  Ruby_TheClass(const RubyNil&) {}

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
