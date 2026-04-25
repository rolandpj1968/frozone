#include "../runtime/box_first.hpp"

namespace Ruby {

struct BasicObject;
struct Object;
struct NilClass;
struct TrueClass;
struct FalseClass;
struct Integer;
struct Array;
struct Module;
struct Class;
struct Symbol;
struct Numeric;
struct Float;
struct String;
struct Hash;
struct Refinement;
struct Proc;
struct Method;
struct UnboundMethod;
struct Range;
struct Enumerator;
struct Exception;
struct ScriptError;
struct LoadError;
struct SyntaxError;
struct NotImplementedError;
struct SignalException;
struct Interrupt;
struct SystemExit;
struct StandardError;
struct RuntimeError;
struct FrozenError;
struct NameError;
struct NoMethodError;
struct TypeError;
struct ArgumentError;
struct RangeError;
struct FloatDomainError;
struct ZeroDivisionError;
struct IndexError;
struct FiberError;
struct ThreadError;
struct NoMemoryError;
struct SecurityError;
struct SystemStackError;
struct NoMatchingPatternError;
struct KeyError;
struct StopIteration;
struct ClosedQueueError;
struct UncaughtThrowError;
struct LocalJumpError;
struct SystemCallError;
struct IOError;
struct EOFError;
struct EncodingError;
struct RegexpError;
struct Encoding;
struct MatchData;
struct Regexp;
struct Rational;
struct Complex;
struct IO;
struct File;
struct Dir;
struct Time;
struct Mutex;
struct Fiber;
struct ThreadKill;
struct Thread;
struct ThreadGroup;
struct ConditionVariable;
struct Queue;
struct SizedQueue;
struct Process;
struct Binding;
struct PP;
struct StringIO;
struct Struct;
struct Data;
struct Set;
struct Random;
struct ENVClass;

inline BasicObject* nil_instance();
inline BasicObject* true_instance();
inline BasicObject* false_instance();
inline BasicObject* boxed_bool(bool b);
inline bool truthy(BasicObject* o);
inline void ruby_puts(BasicObject* o);
inline BasicObject* k_STDOUT();
inline BasicObject* k_STDERR();
inline BasicObject* k_STDIN();
inline BasicObject* k_ENV();
inline BasicObject* k_RUBY_VERSION();
inline BasicObject* k_RUBY_PLATFORM();
inline BasicObject* k_RUBY_ENGINE();
inline BasicObject* k_RUBY_ENGINE_VERSION();
inline BasicObject* k_RUBY_REVISION();
inline BasicObject* k_RUBY_RELEASE_DATE();
inline BasicObject* k_RUBY_DESCRIPTION();
inline BasicObject* k_RUBY_NAME();
inline BasicObject* k_RUBY_COPYRIGHT();
inline BasicObject* k_RUBY_EXE();
inline BasicObject* k_TOPLEVEL_BINDING();
inline BasicObject* k_ARGF();

struct BasicObject {
  // All box-first allocations route through Boehm. Without
  // this, plain `new X(...)` uses libc malloc and Boehm never
  // collects — instant OOM on any allocation-heavy benchmark.
  static void* operator new(std::size_t n) { return GC_MALLOC(n); }
  static void operator delete(void*) {}  // Boehm collects
  
  virtual ~BasicObject() = default;
  virtual const char* ruby_class_name() const { return "BasicObject"; }
  // method_missing — base aborts; subclasses can override.
  virtual BasicObject* method_missing(const char* method_name) {
    std::fprintf(stderr, "[box-first] method_missing: %s#%s\n", ruby_class_name(), method_name);
    std::abort();
  }
  // Universal method surface — populated from the program's call universe.
  virtual BasicObject* m_minus(BasicObject*) { return method_missing("-"); }
  virtual BasicObject* m_lshift(BasicObject*) { return method_missing("<<"); }
  virtual BasicObject* m_ge(BasicObject*) { return method_missing(">="); }
  virtual BasicObject* m_bit_and(BasicObject*) { return method_missing("&"); }
  virtual BasicObject* m_bit_or(BasicObject*) { return method_missing("|"); }
  virtual BasicObject* m_aref(BasicObject*) { return method_missing("[]"); }
  virtual BasicObject* m_ne_q(BasicObject*) { return method_missing("!="); }
  virtual BasicObject* m_rshift(BasicObject*) { return method_missing(">>"); }
  virtual BasicObject* m_bit_xor(BasicObject*) { return method_missing("^"); }
  virtual BasicObject* m_plus(BasicObject*) { return method_missing("+"); }
  virtual BasicObject* m_lt(BasicObject*) { return method_missing("<"); }
  virtual BasicObject* m_mul(BasicObject*) { return method_missing("mul"); }
  virtual BasicObject* m_div(BasicObject*) { return method_missing("div"); }
  virtual BasicObject* m_mod(BasicObject*) { return method_missing("mod"); }
  virtual BasicObject* m_gt(BasicObject*) { return method_missing("gt"); }
  virtual BasicObject* m_le(BasicObject*) { return method_missing("le"); }
  virtual BasicObject* m_eq_q(BasicObject*) { return method_missing("eq_q"); }
  virtual BasicObject* m_neg() { return method_missing("neg"); }
  virtual BasicObject* m_size() { return method_missing("size"); }
  virtual BasicObject* m_length() { return method_missing("length"); }
  virtual BasicObject* m_empty_q() { return method_missing("empty_q"); }
  virtual BasicObject* m_first() { return method_missing("first"); }
  virtual BasicObject* m_last() { return method_missing("last"); }
  virtual BasicObject* m_aset(BasicObject*, BasicObject*) { return method_missing("aset"); }
  virtual BasicObject* m_push(BasicObject*) { return method_missing("push"); }
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
  BasicObject* m_mul(BasicObject* other) override {
    return new Integer(raw_ * static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_div(BasicObject* other) override {
    return new Integer(raw_ / static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_mod(BasicObject* other) override {
    return new Integer(raw_ % static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_lt(BasicObject* other) override {
    return boxed_bool(raw_ <  static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_gt(BasicObject* other) override {
    return boxed_bool(raw_ >  static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_le(BasicObject* other) override {
    return boxed_bool(raw_ <= static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_ge(BasicObject* other) override {
    return boxed_bool(raw_ >= static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_eq_q(BasicObject* other) override {
    auto* o = dynamic_cast<Integer*>(other); return boxed_bool(o && raw_ == o->raw_);
  }
  BasicObject* m_ne_q(BasicObject* other) override {
    auto* o = dynamic_cast<Integer*>(other); return boxed_bool(!o || raw_ != o->raw_);
  }
  BasicObject* m_lshift(BasicObject* other) override {
    return new Integer(raw_ << static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_rshift(BasicObject* other) override {
    return new Integer(raw_ >> static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_bit_and(BasicObject* other) override {
    return new Integer(raw_ &  static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_bit_or(BasicObject* other) override {
    return new Integer(raw_ |  static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_bit_xor(BasicObject* other) override {
    return new Integer(raw_ ^  static_cast<Integer*>(other)->raw_);
  }
  BasicObject* m_neg() override {
    return new Integer(-raw_);
  }
};

struct Array : Object {
  // Vector uses GcAllocator so the buffer stays scanned by Boehm.
  std::vector<BasicObject*, GcAllocator<BasicObject*>> data;
  Array() = default;
  Array(std::initializer_list<BasicObject*> init) : data(init.begin(), init.end()) {}
  // Array.new(size) / Array.new(size, fill)
  Array(BasicObject* size, BasicObject* fill = nullptr) {
    int64_t n = static_cast<Integer*>(size)->raw_;
    data.assign(n, fill ? fill : nil_instance());
  }
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

struct Module : Object {
  const char* ruby_class_name() const override { return "Module"; }
};

struct Class : Module {
  const char* ruby_class_name() const override { return "Class"; }
};

struct Symbol : Object {
  const char* ruby_class_name() const override { return "Symbol"; }
};

struct Numeric : Object {
  const char* ruby_class_name() const override { return "Numeric"; }
};

struct Float : Numeric {
  const char* ruby_class_name() const override { return "Float"; }
};

struct String : Object {
  const char* ruby_class_name() const override { return "String"; }
};

struct Hash : Object {
  const char* ruby_class_name() const override { return "Hash"; }
};

struct Refinement : Module {
  const char* ruby_class_name() const override { return "Refinement"; }
};

struct Proc : Object {
  const char* ruby_class_name() const override { return "Proc"; }
};

struct Method : Object {
  const char* ruby_class_name() const override { return "Method"; }
};

struct UnboundMethod : Object {
  const char* ruby_class_name() const override { return "UnboundMethod"; }
};

struct Range : Object {
  const char* ruby_class_name() const override { return "Range"; }
};

struct Enumerator : Object {
  const char* ruby_class_name() const override { return "Enumerator"; }
};

struct Exception : Object {
  const char* ruby_class_name() const override { return "Exception"; }
};

struct ScriptError : Exception {
  const char* ruby_class_name() const override { return "ScriptError"; }
};

struct LoadError : ScriptError {
  const char* ruby_class_name() const override { return "LoadError"; }
};

struct SyntaxError : ScriptError {
  const char* ruby_class_name() const override { return "SyntaxError"; }
};

struct NotImplementedError : ScriptError {
  const char* ruby_class_name() const override { return "NotImplementedError"; }
};

struct SignalException : Exception {
  const char* ruby_class_name() const override { return "SignalException"; }
};

struct Interrupt : SignalException {
  const char* ruby_class_name() const override { return "Interrupt"; }
};

struct SystemExit : Exception {
  const char* ruby_class_name() const override { return "SystemExit"; }
};

struct StandardError : Exception {
  const char* ruby_class_name() const override { return "StandardError"; }
};

struct RuntimeError : StandardError {
  const char* ruby_class_name() const override { return "RuntimeError"; }
};

struct FrozenError : RuntimeError {
  const char* ruby_class_name() const override { return "FrozenError"; }
};

struct NameError : StandardError {
  const char* ruby_class_name() const override { return "NameError"; }
};

struct NoMethodError : NameError {
  const char* ruby_class_name() const override { return "NoMethodError"; }
};

struct TypeError : StandardError {
  const char* ruby_class_name() const override { return "TypeError"; }
};

struct ArgumentError : StandardError {
  const char* ruby_class_name() const override { return "ArgumentError"; }
};

struct RangeError : StandardError {
  const char* ruby_class_name() const override { return "RangeError"; }
};

struct FloatDomainError : RangeError {
  const char* ruby_class_name() const override { return "FloatDomainError"; }
};

struct ZeroDivisionError : StandardError {
  const char* ruby_class_name() const override { return "ZeroDivisionError"; }
};

struct IndexError : StandardError {
  const char* ruby_class_name() const override { return "IndexError"; }
};

struct FiberError : StandardError {
  const char* ruby_class_name() const override { return "FiberError"; }
};

struct ThreadError : StandardError {
  const char* ruby_class_name() const override { return "ThreadError"; }
};

struct NoMemoryError : Exception {
  const char* ruby_class_name() const override { return "NoMemoryError"; }
};

struct SecurityError : Exception {
  const char* ruby_class_name() const override { return "SecurityError"; }
};

struct SystemStackError : Exception {
  const char* ruby_class_name() const override { return "SystemStackError"; }
};

struct NoMatchingPatternError : StandardError {
  const char* ruby_class_name() const override { return "NoMatchingPatternError"; }
};

struct KeyError : IndexError {
  const char* ruby_class_name() const override { return "KeyError"; }
};

struct StopIteration : IndexError {
  const char* ruby_class_name() const override { return "StopIteration"; }
};

struct ClosedQueueError : StopIteration {
  const char* ruby_class_name() const override { return "ClosedQueueError"; }
};

struct UncaughtThrowError : ArgumentError {
  const char* ruby_class_name() const override { return "UncaughtThrowError"; }
};

struct LocalJumpError : StandardError {
  const char* ruby_class_name() const override { return "LocalJumpError"; }
};

struct SystemCallError : StandardError {
  const char* ruby_class_name() const override { return "SystemCallError"; }
};

struct IOError : StandardError {
  const char* ruby_class_name() const override { return "IOError"; }
};

struct EOFError : IOError {
  const char* ruby_class_name() const override { return "EOFError"; }
};

struct EncodingError : StandardError {
  const char* ruby_class_name() const override { return "EncodingError"; }
};

struct RegexpError : StandardError {
  const char* ruby_class_name() const override { return "RegexpError"; }
};

struct Encoding : Object {
  const char* ruby_class_name() const override { return "Encoding"; }
};

struct MatchData : Object {
  const char* ruby_class_name() const override { return "MatchData"; }
};

struct Regexp : Object {
  const char* ruby_class_name() const override { return "Regexp"; }
};

struct Rational : Numeric {
  const char* ruby_class_name() const override { return "Rational"; }
};

struct Complex : Object {
  const char* ruby_class_name() const override { return "Complex"; }
};

struct IO : Object {
  const char* ruby_class_name() const override { return "IO"; }
};

struct File : IO {
  const char* ruby_class_name() const override { return "File"; }
};

struct Dir : Object {
  const char* ruby_class_name() const override { return "Dir"; }
};

struct Time : Object {
  const char* ruby_class_name() const override { return "Time"; }
};

struct Mutex : Object {
  const char* ruby_class_name() const override { return "Mutex"; }
};

struct Fiber : Object {
  const char* ruby_class_name() const override { return "Fiber"; }
};

struct ThreadKill : Exception {
  const char* ruby_class_name() const override { return "ThreadKill"; }
};

struct Thread : Object {
  const char* ruby_class_name() const override { return "Thread"; }
};

struct ThreadGroup : Object {
  const char* ruby_class_name() const override { return "ThreadGroup"; }
};

struct ConditionVariable : Object {
  const char* ruby_class_name() const override { return "ConditionVariable"; }
};

struct Queue : Object {
  const char* ruby_class_name() const override { return "Queue"; }
};

struct SizedQueue : Queue {
  const char* ruby_class_name() const override { return "SizedQueue"; }
};

struct Process : Object {
  const char* ruby_class_name() const override { return "Process"; }
};

struct Binding : Object {
  const char* ruby_class_name() const override { return "Binding"; }
};

struct PP : Object {
  const char* ruby_class_name() const override { return "PP"; }
};

struct StringIO : Object {
  const char* ruby_class_name() const override { return "StringIO"; }
};

struct Struct : Object {
  const char* ruby_class_name() const override { return "Struct"; }
};

struct Data : Object {
  const char* ruby_class_name() const override { return "Data"; }
};

struct Set : Object {
  const char* ruby_class_name() const override { return "Set"; }
};

struct Random : Object {
  const char* ruby_class_name() const override { return "Random"; }
};

struct ENVClass : Object {
  const char* ruby_class_name() const override { return "ENVClass"; }
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

inline BasicObject* k_STDOUT() {
  static BasicObject* val = new IO(); return val;
}

inline BasicObject* k_STDERR() {
  static BasicObject* val = new IO(); return val;
}

inline BasicObject* k_STDIN() {
  static BasicObject* val = new IO(); return val;
}

inline BasicObject* k_ENV() {
  static BasicObject* val = new ENVClass(); return val;
}

inline BasicObject* k_RUBY_VERSION() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_RUBY_PLATFORM() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_RUBY_ENGINE() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_RUBY_ENGINE_VERSION() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_RUBY_REVISION() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_RUBY_RELEASE_DATE() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_RUBY_DESCRIPTION() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_RUBY_NAME() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_RUBY_COPYRIGHT() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_RUBY_EXE() {
  static BasicObject* val = new String(); return val;
}

inline BasicObject* k_TOPLEVEL_BINDING() {
  static BasicObject* val = new Binding(); return val;
}

inline BasicObject* k_ARGF() {
  static BasicObject* val = new IO(); return val;
}

struct MainObject : Object {
  const char* ruby_class_name() const override { return "MainObject"; }

  virtual BasicObject* m_run_benchmark(BasicObject* __anon_rest__ = nullptr, BasicObject* __anon_block__ = nullptr) {
    return nil_instance();
    return nil_instance();
  }

  virtual BasicObject* m_nq_solve(BasicObject* n) {
    BasicObject* a = (new Array(n, (new Integer(-1LL))));
    BasicObject* l = (new Array(n, (new Integer(0LL))));
    BasicObject* c = (new Array(n, (new Integer(0LL))));
    BasicObject* r = (new Array(n, (new Integer(0LL))));
    BasicObject* y0 = ((new Integer(1LL))->m_lshift(n))->m_minus((new Integer(1LL)));
    BasicObject* m = (new Integer(0LL));
    BasicObject* k = (new Integer(0LL));
    while (truthy(k->m_ge((new Integer(0LL))))) {
      BasicObject* y = (l->m_aref(k)->m_bit_or(c->m_aref(k))->m_bit_or(r->m_aref(k)))->m_bit_and(y0);
      if (truthy((y->m_bit_xor(y0))->m_rshift((a->m_aref(k)->m_plus((new Integer(1LL)))))->m_ne_q((new Integer(0LL))))) {
        BasicObject* i = a->m_aref(k)->m_plus((new Integer(1LL)));
        while (truthy(([&]() -> BasicObject* { auto* _l = i->m_lt(n); return truthy(_l) ? ((y->m_bit_and((new Integer(1LL))->m_lshift(i)))->m_ne_q((new Integer(0LL)))) : _l; }()))) {
          i = i->m_plus((new Integer(1LL)));
        }
        if (truthy(k->m_lt(n->m_minus((new Integer(1LL)))))) {
          BasicObject* z = (new Integer(1LL))->m_lshift(i);
          a->m_aset(k, i);
          k = k->m_plus((new Integer(1LL)));
          l->m_aset(k, (l->m_aref(k->m_minus((new Integer(1LL))))->m_bit_or(z))->m_lshift((new Integer(1LL))));
          c->m_aset(k, c->m_aref(k->m_minus((new Integer(1LL))))->m_bit_or(z));
          r->m_aset(k, (r->m_aref(k->m_minus((new Integer(1LL))))->m_bit_or(z))->m_rshift((new Integer(1LL))));
        } else {
          m = m->m_plus((new Integer(1LL)));
          k = k->m_minus((new Integer(1LL)));
        }
      } else {
        a->m_aset(k, (new Integer(-1LL)));
        k = k->m_minus((new Integer(1LL)));
      }
    }
    return m;
    return nil_instance();
  }

  void __top_level__() {
    ruby_puts(this->m_nq_solve((new Integer(8LL))));
  }
};

}  // namespace Ruby

int main() {
  FROZONE_GC_INIT();
  Ruby::MainObject mo;
  mo.__top_level__();
  return 0;
}
