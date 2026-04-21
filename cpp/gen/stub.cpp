#include "../runtime/frozone.hpp"


struct Ruby_Box : public RubyObject {
  gc_ref<RubyObject> iv_payload;

  Ruby_Box() = default;
  Ruby_Box(auto p) {
    iv_payload = p;
  }
  const char* rb_class_name() const override { return "Box"; }

  gc_ref<RubyObject> payload() {
    return iv_payload;
  }

  auto set_payload(auto __anon_req__) {
    iv_payload = __anon_req__;
    return iv_payload;
  }

};
template<> inline const char* ruby_class_name<Ruby_Box>() { return "Box"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Box> : dustman::FieldList<Ruby_Box, &Ruby_Box::iv_payload> {};
#endif

struct Ruby_Node : public RubyObject {

  Ruby_Node() {
    RUBY_NIL;
  }
  const char* rb_class_name() const override { return "Node"; }

};
template<> inline const char* ruby_class_name<Ruby_Node>() { return "Node"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Node> : dustman::FieldList<Ruby_Node> {};
#endif





int main() {
  FROZONE_GC_INIT();
  gc_local<Ruby_Box> b1 = nullptr;
  gc_local<Ruby_Box> b2 = nullptr;
  (b1 = gc_new<Ruby_Box>(({ RubyHash<RubySymbol, int64_t> _h; _h.store(ruby_sym("a"), INT64_C(1)); _h.store(ruby_sym("b"), INT64_C(2)); _h; })));
  (b2 = gc_new<Ruby_Box>(gc_new<Ruby_Node>()));
  ruby_puts(ruby_class(b1->payload()));
  ruby_puts(ruby_class(b2->payload()));
  FROZONE_GC_SHUTDOWN();
  return 0;
}
