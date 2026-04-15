#include "../runtime/frozone.hpp"


struct Ruby_C {
  struct Impl {
  };
  std::shared_ptr<Impl> p;

  Ruby_C() : p(std::make_shared<Impl>()) {
    RUBY_NIL;
  }
  Ruby_C(const RubyNil&) {}

  auto ruby_func() {
    return 0LL;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_C>() { return "C"; }


static Ruby_C INSTANCE;


int main() {
  Ruby_C instance;
  int64_t count = 0;
  (instance = Ruby_C());
  (count = INT64_C(0));
  for (int64_t _i = 0; _i < INT64_C(500); _i++) {
    for (int64_t i = 0; i < INT64_C(500000); i++) {
      instance.ruby_func();
      instance.ruby_func();
      instance.ruby_func();
      instance.ruby_func();
      instance.ruby_func();
      instance.ruby_func();
      instance.ruby_func();
      instance.ruby_func();
      instance.ruby_func();
      (count = (count + INT64_C(1)));
    };
  }
  ruby_puts(count);
  return 0;
}
