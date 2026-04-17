#include "../runtime/frozone.hpp"


struct Ruby_TheClass {
  struct Impl {
    int64_t iv_v0 = 0;
    int64_t iv_v1 = 0;
    int64_t iv_v2 = 0;
    int64_t iv_levar = 0;
  };
  std::shared_ptr<Impl> p;

  Ruby_TheClass() : p(std::make_shared<Impl>()) {
    p->iv_v0 = INT64_C(1);
    p->iv_v1 = INT64_C(2);
    p->iv_v2 = INT64_C(3);
    p->iv_levar = INT64_C(1);
  }
  Ruby_TheClass(const RubyNil&) {}

  auto get_value_loop() {
    int64_t sum = 0;
    int64_t i = 0;
    (sum = INT64_C(0));
    (i = INT64_C(0));
    while ((i < INT64_C(10000))) {
      (sum = (sum + p->iv_levar));
      (sum = (sum + p->iv_levar));
      (sum = (sum + p->iv_levar));
      (sum = (sum + p->iv_levar));
      (sum = (sum + p->iv_levar));
      (i = (i + INT64_C(1)));
    }
    return sum;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_TheClass>() { return "TheClass"; }


static Ruby_TheClass OBJ;



int main() {
  int64_t last = 0;
  (last = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(300); _i++) {
    (last = OBJ.get_value_loop());
  }
  ruby_puts(last);
  return 0;
}
