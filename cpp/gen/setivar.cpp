#include "../runtime/frozone.hpp"


struct Ruby_TheClass {
  struct Impl {
    int64_t iv_v0 = 0;
    int64_t iv_v1 = 0;
    int64_t iv_v3 = 0;
    int64_t iv_levar = 0;
  };
  std::shared_ptr<Impl> p;

  Ruby_TheClass() : p(std::make_shared<Impl>()) {
    p->iv_v0 = INT64_C(1);
    p->iv_v1 = INT64_C(2);
    p->iv_v3 = INT64_C(3);
    p->iv_levar = INT64_C(1);
  }
  Ruby_TheClass(const RubyNil&) {}

  auto set_value_loop() {
    int64_t i = 0;
    (i = INT64_C(0));
    while ((i < INT64_C(10000))) {
      p->iv_levar = i;
      p->iv_levar = i;
      p->iv_levar = i;
      p->iv_levar = i;
      p->iv_levar = i;
      (i = (i + INT64_C(1)));
    }
    return RubyNil();
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_TheClass>() { return "TheClass"; }




int main() {
  Ruby_TheClass obj;
  std::optional<int64_t> last;
  (obj = Ruby_TheClass());
  (last = ruby_to_opt<int64_t>(INT64_C(0)));
  for (int64_t _i = 0; _i < INT64_C(300); _i++) {
    (last = ruby_to_opt<int64_t>(obj.set_value_loop()));
  }
  ruby_puts(last);
  return 0;
}
