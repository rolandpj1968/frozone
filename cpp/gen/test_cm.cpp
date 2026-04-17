#include "../runtime/frozone.hpp"


struct Ruby_Counter {
  struct Impl {
  };
  std::shared_ptr<Impl> p;

  Ruby_Counter() : p(std::make_shared<Impl>()) {
    (cv_count = (cv_count + INT64_C(1)));
  }
  Ruby_Counter(const RubyNil&) {}

  static inline int64_t cv_count = 0;
  static auto count() {
    return cv_count;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_Counter>() { return "Counter"; }





int main() {
  Ruby_Counter();
  Ruby_Counter();
  ruby_puts(Ruby_Counter::count());
  return 0;
}
