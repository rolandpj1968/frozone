#include "../runtime/box_first.hpp"

namespace Ruby {

struct BasicObject;
struct Object;
struct NilClass;
struct TrueClass;
struct FalseClass;
struct Integer;
struct Array;

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
  virtual BasicObject* m_size() { return method_missing("size"); }
  virtual BasicObject* m_aref(BasicObject*) { return method_missing("[]"); }
  virtual BasicObject* m_push(BasicObject*) { return method_missing("push"); }
  virtual BasicObject* m_first() { return method_missing("first"); }
  virtual BasicObject* m_last() { return method_missing("last"); }
  virtual BasicObject* m_plus(BasicObject*) { return method_missing("plus"); }
  virtual BasicObject* m_minus(BasicObject*) { return method_missing("minus"); }
  virtual BasicObject* m_lt(BasicObject*) { return method_missing("lt"); }
  virtual BasicObject* m_length() { return method_missing("length"); }
  virtual BasicObject* m_empty_q() { return method_missing("empty_q"); }
  virtual BasicObject* m_aset(BasicObject*, BasicObject*) { return method_missing("aset"); }
  virtual BasicObject* m_lshift(BasicObject*) { return method_missing("lshift"); }
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

struct Array : Object {
  std::vector<BasicObject*> data;
  Array() = default;
  Array(std::initializer_list<BasicObject*> init) : data(init) {}
  const char* ruby_class_name() const override { return "Array"; }
  BasicObject* m_size() override {
    return new Integer(static_cast<int64_t>(data.size()));
  }
  BasicObject* m_length() override {
    return new Integer(static_cast<int64_t>(data.size()));
  }
  BasicObject* m_empty_q() override {
    return boxed_bool(data.empty());
  }
  BasicObject* m_first() override {
    return data.empty() ? nil_instance() : data.front();
  }
  BasicObject* m_last() override {
    return data.empty() ? nil_instance() : data.back();
  }
  BasicObject* m_aref(BasicObject* idx) override {
    int64_t i = static_cast<Integer*>(idx)->raw_;
    if (i < 0) i += static_cast<int64_t>(data.size());
    if (i < 0 || i >= static_cast<int64_t>(data.size())) return nil_instance();
    return data[i];
  }
  BasicObject* m_aset(BasicObject* idx, BasicObject* val) override {
    int64_t i = static_cast<Integer*>(idx)->raw_;
    if (i < 0) i += static_cast<int64_t>(data.size());
    if (i >= static_cast<int64_t>(data.size())) data.resize(i + 1, nil_instance());
    data[i] = val;
    return val;
  }
  BasicObject* m_push(BasicObject* val) override {
    data.push_back(val); return this;
  }
  BasicObject* m_lshift(BasicObject* val) override {
    data.push_back(val); return this;
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
    BasicObject* a = new Array({new Integer(10LL), new Integer(20LL), new Integer(30LL), new Integer(40LL), new Integer(50LL)});
    ruby_puts(a->m_size());
    ruby_puts(a->m_aref(new Integer(0LL)));
    ruby_puts(a->m_aref(new Integer(2LL)));
    ruby_puts(a->m_aref(new Integer(-1LL)));
    a->m_push(new Integer(99LL));
    ruby_puts(a->m_size());
    ruby_puts(a->m_aref(new Integer(5LL)));
    ruby_puts(a->m_first());
    ruby_puts(a->m_last());
  }
};

}  // namespace Ruby

int main() {
  FROZONE_GC_INIT();
  Ruby::MainObject mo;
  mo.__top_level__();
  return 0;
}
