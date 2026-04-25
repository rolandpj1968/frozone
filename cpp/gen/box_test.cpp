#include "../runtime/box_first.hpp"

namespace Ruby {

struct BasicObject;
struct Object;
struct NilClass;
struct TrueClass;
struct FalseClass;
struct Integer;
struct Box;

inline BasicObject* nil_instance();
inline BasicObject* true_instance();
inline BasicObject* false_instance();
inline BasicObject* boxed_bool(bool b);
inline bool truthy(BasicObject* o);
inline void ruby_puts(BasicObject* o);

struct BasicObject {
  virtual ~BasicObject() = default;
  virtual const char* ruby_class_name() const { return "BasicObject"; }
  // method_missing — base aborts; subclasses can override.
  virtual BasicObject* method_missing(const char* method_name) {
    std::fprintf(stderr, "[box-first] method_missing: %s#%s\n", ruby_class_name(), method_name);
    std::abort();
  }
  // Universal method surface — populated from the program's call universe.
  virtual BasicObject* m_plus(BasicObject*) { return method_missing("+"); }
  virtual BasicObject* m_value() { return method_missing("value"); }
  virtual BasicObject* m_doubled() { return method_missing("doubled"); }
  virtual BasicObject* m_minus(BasicObject*) { return method_missing("minus"); }
  virtual BasicObject* m_lt(BasicObject*) { return method_missing("lt"); }
};

struct Object : BasicObject {
  const char* ruby_class_name() const override { return "Object"; }
};

struct NilClass : Object {
  const char* ruby_class_name() const override { return "NilClass"; }
};

struct TrueClass : Object {
  const char* ruby_class_name() const override { return "TrueClass"; }
};

struct FalseClass : Object {
  const char* ruby_class_name() const override { return "FalseClass"; }
};

struct Integer : Object {
  explicit Integer(int64_t r) : raw_(r) {}
  const char* ruby_class_name() const override { return "Integer"; }
  int64_t raw_;
  BasicObject* m_plus(BasicObject* other) override {
    return new Integer(raw_ + static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_minus(BasicObject* other) override {
    return new Integer(raw_ - static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_lt(BasicObject* other) override {
    return boxed_bool(raw_ < static_cast<Integer*>(other)->raw_);
  }
};

struct Box : Object {
  const char* ruby_class_name() const override { return "Box"; }
  BasicObject* iv_v = nullptr;
  Box(BasicObject* v) {
    (this->iv_v = v);
  }
  BasicObject* m_value() override {
    return this->iv_v;
    return nil_instance();
  }
  BasicObject* m_doubled() override {
    return this->iv_v->m_plus(this->iv_v);
    return nil_instance();
  }
};

inline NilClass NIL_INSTANCE;
inline TrueClass TRUE_INSTANCE;
inline FalseClass FALSE_INSTANCE;

inline BasicObject* nil_instance() {
  return static_cast<BasicObject*>(&NIL_INSTANCE);
}

inline BasicObject* true_instance() {
  return static_cast<BasicObject*>(&TRUE_INSTANCE);
}

inline BasicObject* false_instance() {
  return static_cast<BasicObject*>(&FALSE_INSTANCE);
}

inline BasicObject* boxed_bool(bool b) {
  return b ? true_instance() : false_instance();
}

inline bool truthy(BasicObject* o) {
  return o != nil_instance() && o != false_instance();
}

inline void ruby_puts(BasicObject* o) {
  if (auto* i = dynamic_cast<Integer*>(o)) {
    std::printf("%lld\n", static_cast<long long>(i->raw_));
  } else {
    std::printf("(unprintable: %s)\n", o->ruby_class_name());
  }
}

struct MainObject : Object {
  const char* ruby_class_name() const override { return "MainObject"; }

  virtual BasicObject* run_benchmark(BasicObject* __anon_rest__ = nullptr, BasicObject* __anon_block__ = nullptr) {
    return nil_instance();
    return nil_instance();
  }

  void __top_level__() {
    BasicObject* b = new Box(new Integer(42LL));
    ruby_puts(b->m_value());
    ruby_puts(b->m_doubled());
  }
};

}  // namespace Ruby

int main() {
  FROZONE_GC_INIT();
  Ruby::MainObject mo;
  mo.__top_level__();
  return 0;
}
