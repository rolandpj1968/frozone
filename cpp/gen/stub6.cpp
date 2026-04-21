#include "../runtime/frozone.hpp"


struct Ruby_Holder : public RubyObject {
  RubyNil iv_slot;

  Ruby_Holder() {
    iv_slot = RUBY_NIL;
  }
  const char* rb_class_name() const override { return "Holder"; }

  auto slot() {
    return iv_slot;
  }

  auto set_slot(auto __anon_req__) {
    iv_slot = __anon_req__;
    return iv_slot;
  }

};
template<> inline const char* ruby_class_name<Ruby_Holder>() { return "Holder"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Holder> : dustman::FieldList<Ruby_Holder> {};
#endif

struct Ruby_Thing : public RubyObject {

  Ruby_Thing() {
    RUBY_NIL;
  }
  const char* rb_class_name() const override { return "Thing"; }

};
template<> inline const char* ruby_class_name<Ruby_Thing>() { return "Thing"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Thing> : dustman::FieldList<Ruby_Thing> {};
#endif





int main() {
  FROZONE_GC_INIT();
  gc_local<Ruby_Holder> h = nullptr;
  (h = gc_new<Ruby_Holder>());
  ruby_puts(ruby_class(h->slot()));
  h->set_slot(gc_new<Ruby_Thing>());
  ruby_puts(ruby_class(h->slot()));
  h->set_slot(RUBY_NIL);
  ruby_puts(ruby_class(h->slot()));
  FROZONE_GC_SHUTDOWN();
  return 0;
}
