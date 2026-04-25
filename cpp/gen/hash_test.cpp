#include "../runtime/box_first.hpp"

namespace Ruby {

struct BasicObject;
struct Object;
struct NilClass;
struct TrueClass;
struct FalseClass;
struct Integer;
struct Array;
struct Symbol;
struct Hash;
struct Module;
struct Class;
struct Numeric;
struct Float;
struct String;
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
inline Symbol* intern(const char* name);
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
  // Hand-coded m_eq_q / m_hash_value — these are special:
  // they need sensible *defaults* (pointer identity), not
  // method_missing, otherwise Hash key lookup would crash on
  // any class without an explicit override. Subclasses with
  // value semantics (Integer, Float, String) override.
  virtual BasicObject* m_eq_q(BasicObject* other) { return boxed_bool(this == other); }
  virtual std::size_t m_hash_value() const { return reinterpret_cast<std::size_t>(this); }
  // Universal method surface — populated from the program's call universe.
  virtual BasicObject* m_aref(BasicObject*) { return method_missing("[]"); }
  virtual BasicObject* m_size() { return method_missing("size"); }
  virtual BasicObject* m_has_key_q(BasicObject*) { return method_missing("has_key?"); }
  virtual BasicObject* m_plus(BasicObject*) { return method_missing("plus"); }
  virtual BasicObject* m_minus(BasicObject*) { return method_missing("minus"); }
  virtual BasicObject* m_mul(BasicObject*) { return method_missing("mul"); }
  virtual BasicObject* m_div(BasicObject*) { return method_missing("div"); }
  virtual BasicObject* m_mod(BasicObject*) { return method_missing("mod"); }
  virtual BasicObject* m_lt(BasicObject*) { return method_missing("lt"); }
  virtual BasicObject* m_gt(BasicObject*) { return method_missing("gt"); }
  virtual BasicObject* m_le(BasicObject*) { return method_missing("le"); }
  virtual BasicObject* m_ge(BasicObject*) { return method_missing("ge"); }
  virtual BasicObject* m_ne_q(BasicObject*) { return method_missing("ne_q"); }
  virtual BasicObject* m_lshift(BasicObject*) { return method_missing("lshift"); }
  virtual BasicObject* m_rshift(BasicObject*) { return method_missing("rshift"); }
  virtual BasicObject* m_bit_and(BasicObject*) { return method_missing("bit_and"); }
  virtual BasicObject* m_bit_or(BasicObject*) { return method_missing("bit_or"); }
  virtual BasicObject* m_bit_xor(BasicObject*) { return method_missing("bit_xor"); }
  virtual BasicObject* m_neg() { return method_missing("neg"); }
  virtual BasicObject* m_length() { return method_missing("length"); }
  virtual BasicObject* m_empty_q() { return method_missing("empty_q"); }
  virtual BasicObject* m_first() { return method_missing("first"); }
  virtual BasicObject* m_last() { return method_missing("last"); }
  virtual BasicObject* m_aset(BasicObject*, BasicObject*) { return method_missing("aset"); }
  virtual BasicObject* m_push(BasicObject*) { return method_missing("push"); }
  virtual BasicObject* m_include_q(BasicObject*) { return method_missing("include_q"); }
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
  // m_hash_value override — value-based so Integer keys hash
  // equal regardless of box identity.
  std::size_t m_hash_value() const override { return std::hash<int64_t>()(raw_); }
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

struct Symbol : Object {
  const char* name_;
  explicit Symbol(const char* name) : name_(name) {}
  const char* ruby_class_name() const override { return "Symbol"; }
};

struct Hash : Object {
  // Vtable-aware hash + key-equality.
  struct Hasher {
    std::size_t operator()(BasicObject* v) const { return v->m_hash_value(); }
  };
  struct KeyEq {
    bool operator()(BasicObject* a, BasicObject* b) const {
      return a->m_eq_q(b) == true_instance();
    }
  };
  using map_t = std::unordered_map<
    BasicObject*, BasicObject*, Hasher, KeyEq,
    GcAllocator<std::pair<BasicObject* const, BasicObject*>>>;
  map_t data;
  Hash() = default;
  Hash(std::initializer_list<std::pair<BasicObject*, BasicObject*>> init) {
    for (auto& p : init) data.insert(p);
  }
  const char* ruby_class_name() const override { return "Hash"; }
  BasicObject* m_size() override {
    return new Integer(static_cast<int64_t>(data.size()));
  }
  BasicObject* m_length() override {
    return new Integer(static_cast<int64_t>(data.size()));
  }
  BasicObject* m_empty_q() override {
    return boxed_bool(data.empty());
  }
  BasicObject* m_aref(BasicObject* k) override {
    auto it = data.find(k);
    return (it == data.end()) ? nil_instance() : it->second;
  }
  BasicObject* m_aset(BasicObject* k, BasicObject* v) override {
    data[k] = v; return v;
  }
  BasicObject* m_include_q(BasicObject* k) override {
    return boxed_bool(data.find(k) != data.end());
  }
  BasicObject* m_has_key_q(BasicObject* k) override {
    return boxed_bool(data.find(k) != data.end());
  }
};

struct Module : Object {
  const char* ruby_class_name() const override { return "Module"; }
};

struct Class : Module {
  const char* ruby_class_name() const override { return "Class"; }
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
  if (auto* i = dynamic_cast<Integer*>(o))      { std::printf("%lld\n", static_cast<long long>(i->raw_)); return; }
  if (auto* s = dynamic_cast<Symbol*>(o))       { std::printf("%s\n", s->name_); return; }
  if (o == true_instance())                      { std::printf("true\n"); return; }
  if (o == false_instance())                     { std::printf("false\n"); return; }
  if (o == nil_instance())                       { std::printf("\n"); return; }
  std::printf("(unprintable: %s)\n", o->ruby_class_name());
}

inline Symbol* intern(const char* name) {
  using Tab = std::unordered_map<std::string, Symbol*,
    std::hash<std::string>, std::equal_to<std::string>,
    GcAllocator<std::pair<const std::string, Symbol*>>>;
  static Tab table;
  auto it = table.find(name);
  if (it != table.end()) return it->second;
  Symbol* s = new Symbol(name);
  table[std::string(name)] = s;
  return s;
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

inline BasicObject* k_ARGF() {
  static BasicObject* val = new IO(); return val;
}

struct MainObject : Object {
  const char* ruby_class_name() const override { return "MainObject"; }

  virtual BasicObject* m_run_benchmark(BasicObject* __anon_rest__ = nullptr, BasicObject* __anon_block__ = nullptr) {
    return nil_instance();
    return nil_instance();
  }

  void __top_level__() {
    BasicObject* h = (new Hash({{intern("foo"), (new Integer(10LL))}, {intern("bar"), (new Integer(20LL))}, {intern("baz"), (new Integer(30LL))}}));
    ruby_puts(h->m_aref(intern("foo")));
    ruby_puts(h->m_aref(intern("bar")));
    ruby_puts(h->m_aref(intern("baz")));
    ruby_puts(h->m_size());
    BasicObject* g = (new Hash({{(new Integer(1LL)), (new Integer(100LL))}, {(new Integer(2LL)), (new Integer(200LL))}, {(new Integer(3LL)), (new Integer(300LL))}}));
    ruby_puts(g->m_aref((new Integer(1LL))));
    ruby_puts(g->m_aref((new Integer(2LL))));
    ruby_puts(g->m_aref((new Integer(3LL))));
    ruby_puts(g->m_size());
    h->m_aset(intern("qux"), (new Integer(99LL)));
    ruby_puts(h->m_aref(intern("qux")));
    ruby_puts(h->m_size());
    ruby_puts(h->m_has_key_q(intern("foo")));
    ruby_puts(h->m_has_key_q(intern("nonexistent")));
  }
};

}  // namespace Ruby

int main() {
  FROZONE_GC_INIT();
  Ruby::MainObject mo;
  mo.__top_level__();
  return 0;
}
