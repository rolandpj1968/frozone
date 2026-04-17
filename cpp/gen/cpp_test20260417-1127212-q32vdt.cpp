#include "../runtime/frozone.hpp"


struct Ruby_Foo {
  struct Impl {
  };
  std::shared_ptr<Impl> p;

  Ruby_Foo() : p(std::make_shared<Impl>()) {
    /* UNSUPPORTED: ClassVariableWrite */;
  }
  Ruby_Foo(const RubyNil&) {}

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_Foo>() { return "Foo"; }





int main() {
  Ruby_Foo();
  Ruby_Foo();
  ruby_puts(Foo.count());
  return 0;
}
