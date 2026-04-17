#include "../runtime/frozone.hpp"


struct Ruby_C {
  struct Impl {
    int64_t iv_a = 0;
    int64_t iv_b = 0;
    int64_t iv_c = 0;
    int64_t iv_d = 0;
  };
  std::shared_ptr<Impl> p;

  Ruby_C() = default;
  Ruby_C(const RubyNil&) {}
  Ruby_C(auto a, auto b, auto c, auto d) : p(std::make_shared<Impl>()) {
    p->iv_a = a;
    p->iv_b = b;
    p->iv_c = c;
    p->iv_d = d;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_C>() { return "C"; }




static auto test() {
  return Ruby_C(INT64_C(1), INT64_C(2), INT64_C(3), INT64_C(4));
}


int main() {
  Ruby_C last;
  int64_t i = 0;
  (last = RUBY_NIL);
  for (int64_t _i = 0; _i < INT64_C(300); _i++) {
    (i = INT64_C(0));
    while ((i < INT64_C(1000))) {
      (last = test());
      (i = (i + INT64_C(1)));
    };
  }
  ruby_puts(ruby_class(last));
  return 0;
}
