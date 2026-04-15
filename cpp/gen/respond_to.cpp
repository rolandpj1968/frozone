#include "../runtime/frozone.hpp"


struct Ruby_A {
  struct Impl {
  };
  std::shared_ptr<Impl> p;

  Ruby_A() : p(std::make_shared<Impl>()) {
    RUBY_NIL;
  }
  Ruby_A(const RubyNil&) {}

  auto foo() {
    return 0LL;
  }

  auto foo2() {
    return 0LL;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_A>() { return "A"; }

struct Ruby_B {
  struct Impl {
  };
  std::shared_ptr<Impl> p;

  Ruby_B() = default;
  Ruby_B(const RubyNil&) {}

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_B>() { return "B"; }

struct Ruby_C {
  struct Impl {
  };
  std::shared_ptr<Impl> p;

  Ruby_C() = default;
  Ruby_C(const RubyNil&) {}

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_C>() { return "C"; }




int main() {
  Ruby_A a;
  Ruby_B b;
  Ruby_C c;
  bool last = false;
  (a = Ruby_A());
  (b = Ruby_B());
  (c = Ruby_C());
  (last = false);
  for (int64_t _i = 0; _i < INT64_C(1000); _i++) {
    for (int64_t i = 0; i < INT64_C(500000); i++) {
      true;
      true;
      false;
      false;
      false;
      false;
      false;
      false;
      false;
      false;
      false;
      (last = false);
    };
  }
  ruby_puts(last);
  return 0;
}
