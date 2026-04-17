#include "../runtime/frozone.hpp"


struct Ruby_Counter {
  struct Impl {
  };
  std::shared_ptr<Impl> p;

  Ruby_Counter() : p(std::make_shared<Impl>()) {
    /* UNSUPPORTED: ClassVariableWrite */;
  }
  Ruby_Counter(const RubyNil&) {}

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_Counter>() { return "Counter"; }





int main() {
  Ruby_Foo();
  Ruby_Foo();
  ruby_puts(Foo.count());
  return 0;
}
