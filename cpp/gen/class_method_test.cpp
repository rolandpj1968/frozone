#include "../runtime/box_first.hpp"

namespace Ruby {

struct BasicObject;
struct Object;
struct Class;
struct NilClass;
struct TrueClass;
struct FalseClass;
struct Integer;
struct Float;
struct Array;
struct Symbol;
struct String;
struct Hash;
struct Module;
struct Numeric;
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
struct Counter;
struct BasicObject_eigenclass;
struct Object_eigenclass;
struct NilClass_eigenclass;
struct TrueClass_eigenclass;
struct FalseClass_eigenclass;
struct Integer_eigenclass;
struct Float_eigenclass;
struct Array_eigenclass;
struct Symbol_eigenclass;
struct String_eigenclass;
struct Hash_eigenclass;
struct Module_eigenclass;
struct Numeric_eigenclass;
struct Refinement_eigenclass;
struct Proc_eigenclass;
struct Method_eigenclass;
struct UnboundMethod_eigenclass;
struct Range_eigenclass;
struct Enumerator_eigenclass;
struct Exception_eigenclass;
struct ScriptError_eigenclass;
struct LoadError_eigenclass;
struct SyntaxError_eigenclass;
struct NotImplementedError_eigenclass;
struct SignalException_eigenclass;
struct Interrupt_eigenclass;
struct SystemExit_eigenclass;
struct StandardError_eigenclass;
struct RuntimeError_eigenclass;
struct FrozenError_eigenclass;
struct NameError_eigenclass;
struct NoMethodError_eigenclass;
struct TypeError_eigenclass;
struct ArgumentError_eigenclass;
struct RangeError_eigenclass;
struct FloatDomainError_eigenclass;
struct ZeroDivisionError_eigenclass;
struct IndexError_eigenclass;
struct FiberError_eigenclass;
struct ThreadError_eigenclass;
struct NoMemoryError_eigenclass;
struct SecurityError_eigenclass;
struct SystemStackError_eigenclass;
struct NoMatchingPatternError_eigenclass;
struct KeyError_eigenclass;
struct StopIteration_eigenclass;
struct ClosedQueueError_eigenclass;
struct UncaughtThrowError_eigenclass;
struct LocalJumpError_eigenclass;
struct SystemCallError_eigenclass;
struct IOError_eigenclass;
struct EOFError_eigenclass;
struct EncodingError_eigenclass;
struct RegexpError_eigenclass;
struct Encoding_eigenclass;
struct MatchData_eigenclass;
struct Regexp_eigenclass;
struct Rational_eigenclass;
struct Complex_eigenclass;
struct IO_eigenclass;
struct File_eigenclass;
struct Dir_eigenclass;
struct Time_eigenclass;
struct Mutex_eigenclass;
struct Fiber_eigenclass;
struct ThreadKill_eigenclass;
struct Thread_eigenclass;
struct ThreadGroup_eigenclass;
struct ConditionVariable_eigenclass;
struct Queue_eigenclass;
struct SizedQueue_eigenclass;
struct Process_eigenclass;
struct Binding_eigenclass;
struct PP_eigenclass;
struct StringIO_eigenclass;
struct Struct_eigenclass;
struct Data_eigenclass;
struct Set_eigenclass;
struct Random_eigenclass;
struct ENVClass_eigenclass;
struct Counter_eigenclass;

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
  // m_case_eq (===) defaults to m_eq_q per Ruby semantics.
  // Class objects override on the eigenclass to do is_a? check.
  virtual BasicObject* m_case_eq(BasicObject* other) { return m_eq_q(other); }
  // Universal method surface — populated from the program's call universe.
  virtual BasicObject* m_create_with(BasicObject*) { return method_missing("create_with"); }
  virtual BasicObject* m_value() { return method_missing("value"); }
  virtual BasicObject* m_zero() { return method_missing("zero"); }
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
  virtual BasicObject* m_size() { return method_missing("size"); }
  virtual BasicObject* m_length() { return method_missing("length"); }
  virtual BasicObject* m_empty_q() { return method_missing("empty_q"); }
  virtual BasicObject* m_first() { return method_missing("first"); }
  virtual BasicObject* m_last() { return method_missing("last"); }
  virtual BasicObject* m_aref(BasicObject*) { return method_missing("aref"); }
  virtual BasicObject* m_aset(BasicObject*, BasicObject*) { return method_missing("aset"); }
  virtual BasicObject* m_push(BasicObject*) { return method_missing("push"); }
  virtual BasicObject* m_bytesize() { return method_missing("bytesize"); }
  virtual BasicObject* m_to_s() { return method_missing("to_s"); }
  virtual BasicObject* m_ord() { return method_missing("ord"); }
  virtual BasicObject* m_dup() { return method_missing("dup"); }
  virtual BasicObject* m_b() { return method_missing("b"); }
  virtual BasicObject* m_include_q(BasicObject*) { return method_missing("include_q"); }
  virtual BasicObject* m_has_key_q(BasicObject*) { return method_missing("has_key_q"); }
};

struct Object : BasicObject {
  const char* ruby_class_name() const override { return "Object"; }
};

struct Class : Object {
  const char* ruby_class_name() const override { return "Class"; }
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

struct Float : Object {
  explicit Float(double r) : raw_(r) {}
  const char* ruby_class_name() const override { return "Float"; }
  std::size_t m_hash_value() const override { return std::hash<double>()(raw_); }
  double raw_;
  BasicObject* m_plus(BasicObject* other) override {
    return new Float(raw_ + static_cast<Float*>(other)->raw_);
  }
  BasicObject* m_minus(BasicObject* other) override {
    return new Float(raw_ - static_cast<Float*>(other)->raw_);
  }
  BasicObject* m_mul(BasicObject* other) override {
    return new Float(raw_ * static_cast<Float*>(other)->raw_);
  }
  BasicObject* m_div(BasicObject* other) override {
    return new Float(raw_ / static_cast<Float*>(other)->raw_);
  }
  BasicObject* m_lt(BasicObject* other) override {
    return boxed_bool(raw_ <  static_cast<Float*>(other)->raw_);
  }
  BasicObject* m_gt(BasicObject* other) override {
    return boxed_bool(raw_ >  static_cast<Float*>(other)->raw_);
  }
  BasicObject* m_le(BasicObject* other) override {
    return boxed_bool(raw_ <= static_cast<Float*>(other)->raw_);
  }
  BasicObject* m_ge(BasicObject* other) override {
    return boxed_bool(raw_ >= static_cast<Float*>(other)->raw_);
  }
  BasicObject* m_eq_q(BasicObject* other) override {
    auto* o = dynamic_cast<Float*>(other); return boxed_bool(o && raw_ == o->raw_);
  }
  BasicObject* m_ne_q(BasicObject* other) override {
    auto* o = dynamic_cast<Float*>(other); return boxed_bool(!o || raw_ != o->raw_);
  }
  BasicObject* m_neg() override {
    return new Float(-raw_);
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
  private:
    explicit Symbol(const char* name) : name_(name) {}
    friend Symbol* intern(const char* name);
  public:
  const char* ruby_class_name() const override { return "Symbol"; }
};

struct String : Object {
  enum Enc { UTF8 = 0, BINARY = 1 };
  std::vector<std::uint8_t, GcAllocator<std::uint8_t>> bytes;
  Enc enc = UTF8;
  mutable std::int64_t length_cache_ = -1;
  
  String() = default;
  String(const char* s) { if (s) { auto n = std::strlen(s); bytes.assign(s, s + n); } }
  String(const char* s, std::size_t n) { bytes.assign(s, s + n); }
  String(const char* s, std::size_t n, Enc e) : enc(e) { bytes.assign(s, s + n); }
  
  const char* ruby_class_name() const override { return "String"; }
  
  // Codepoint-aware length for UTF-8 (cached); byte count for BINARY.
  std::int64_t length() const {
    if (enc == BINARY) return static_cast<std::int64_t>(bytes.size());
    if (length_cache_ < 0) {
      std::int64_t n = 0;
      for (auto b : bytes) if ((b & 0xC0) != 0x80) n++;
      length_cache_ = n;
    }
    return length_cache_;
  }
  bool has_non_ascii() const { for (auto b : bytes) if (b >= 0x80) return true; return false; }
  
  // Hash on byte sequence — equal byte sequences hash equal.
  std::size_t m_hash_value() const override {
    std::size_t h = 0xcbf29ce484222325ULL;  // FNV-1a offset
    for (auto b : bytes) { h ^= b; h *= 0x100000001b3ULL; }
    return h;
  }
  BasicObject* m_size() override {
    return new Integer(length());
  }
  BasicObject* m_length() override {
    return new Integer(length());
  }
  BasicObject* m_bytesize() override {
    return new Integer(static_cast<std::int64_t>(bytes.size()));
  }
  BasicObject* m_empty_q() override {
    return boxed_bool(bytes.empty());
  }
  BasicObject* m_to_s() override {
    return this;
  }
  BasicObject* m_eq_q(BasicObject* other) override {
    auto* o = dynamic_cast<String*>(other); return boxed_bool(o && bytes == o->bytes);
  }
  BasicObject* m_ne_q(BasicObject* other) override {
    auto* o = dynamic_cast<String*>(other); return boxed_bool(!o || bytes != o->bytes);
  }
  BasicObject* m_lt(BasicObject* other) override {
    return boxed_bool(bytes <  static_cast<String*>(other)->bytes);
  }
  BasicObject* m_gt(BasicObject* other) override {
    return boxed_bool(bytes >  static_cast<String*>(other)->bytes);
  }
  BasicObject* m_le(BasicObject* other) override {
    return boxed_bool(bytes <= static_cast<String*>(other)->bytes);
  }
  BasicObject* m_ge(BasicObject* other) override {
    return boxed_bool(bytes >= static_cast<String*>(other)->bytes);
  }
  BasicObject* m_plus(BasicObject* other) override {
    auto* o = static_cast<String*>(other);
    String* r = new String();
    r->enc = (enc == BINARY && o->enc == UTF8 && o->has_non_ascii()) ? UTF8 : enc;
    r->bytes.reserve(bytes.size() + o->bytes.size());
    r->bytes.insert(r->bytes.end(), bytes.begin(), bytes.end());
    r->bytes.insert(r->bytes.end(), o->bytes.begin(), o->bytes.end());
    return r;
  }
  BasicObject* m_lshift(BasicObject* other) override {
    auto* o = static_cast<String*>(other);
    // MRI encoding promotion: BINARY + UTF-8 non-ASCII → UTF-8.
    if (enc == BINARY && o->enc == UTF8 && o->has_non_ascii()) enc = UTF8;
    bytes.insert(bytes.end(), o->bytes.begin(), o->bytes.end());
    length_cache_ = -1;
    return this;
  }
  BasicObject* m_aref(BasicObject* idx) override {
    std::int64_t i = static_cast<Integer*>(idx)->raw_;
    if (i < 0) i += static_cast<std::int64_t>(bytes.size());
    if (i < 0 || i >= static_cast<std::int64_t>(bytes.size())) return nil_instance();
    return new String(reinterpret_cast<const char*>(&bytes[i]), 1, enc);
  }
  BasicObject* m_ord() override {
    return new Integer(bytes.empty() ? 0 : static_cast<std::int64_t>(bytes[0]));
  }
  BasicObject* m_dup() override {
    String* r = new String();
    r->bytes = bytes;
    r->enc = enc;
    return r;
  }
  BasicObject* m_b() override {
    String* r = new String();
    r->bytes = bytes;
    r->enc = BINARY;
    return r;
  }
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

struct Numeric : Object {
  const char* ruby_class_name() const override { return "Numeric"; }
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

struct Counter : Object {
  const char* ruby_class_name() const override { return "Counter"; }
  BasicObject* iv_n = nullptr;
  Counter(BasicObject* n) {
    (this->iv_n = n);
  }
  BasicObject* m_value() override {
    return this->iv_n;
    return nil_instance();
  }
};

struct BasicObject_eigenclass : Class {
  const char* ruby_class_name() const override { return "BasicObject"; }
};

struct Object_eigenclass : Class {
  const char* ruby_class_name() const override { return "Object"; }
};

struct NilClass_eigenclass : Class {
  const char* ruby_class_name() const override { return "NilClass"; }
};

struct TrueClass_eigenclass : Class {
  const char* ruby_class_name() const override { return "TrueClass"; }
};

struct FalseClass_eigenclass : Class {
  const char* ruby_class_name() const override { return "FalseClass"; }
};

struct Integer_eigenclass : Class {
  const char* ruby_class_name() const override { return "Integer"; }
};

struct Float_eigenclass : Class {
  const char* ruby_class_name() const override { return "Float"; }
};

struct Array_eigenclass : Class {
  const char* ruby_class_name() const override { return "Array"; }
};

struct Symbol_eigenclass : Class {
  const char* ruby_class_name() const override { return "Symbol"; }
};

struct String_eigenclass : Class {
  const char* ruby_class_name() const override { return "String"; }
};

struct Hash_eigenclass : Class {
  const char* ruby_class_name() const override { return "Hash"; }
};

struct Module_eigenclass : Class {
  const char* ruby_class_name() const override { return "Module"; }
};

struct Numeric_eigenclass : Class {
  const char* ruby_class_name() const override { return "Numeric"; }
};

struct Refinement_eigenclass : Class {
  const char* ruby_class_name() const override { return "Refinement"; }
};

struct Proc_eigenclass : Class {
  const char* ruby_class_name() const override { return "Proc"; }
};

struct Method_eigenclass : Class {
  const char* ruby_class_name() const override { return "Method"; }
};

struct UnboundMethod_eigenclass : Class {
  const char* ruby_class_name() const override { return "UnboundMethod"; }
};

struct Range_eigenclass : Class {
  const char* ruby_class_name() const override { return "Range"; }
};

struct Enumerator_eigenclass : Class {
  const char* ruby_class_name() const override { return "Enumerator"; }
};

struct Exception_eigenclass : Class {
  const char* ruby_class_name() const override { return "Exception"; }
};

struct ScriptError_eigenclass : Class {
  const char* ruby_class_name() const override { return "ScriptError"; }
};

struct LoadError_eigenclass : Class {
  const char* ruby_class_name() const override { return "LoadError"; }
};

struct SyntaxError_eigenclass : Class {
  const char* ruby_class_name() const override { return "SyntaxError"; }
};

struct NotImplementedError_eigenclass : Class {
  const char* ruby_class_name() const override { return "NotImplementedError"; }
};

struct SignalException_eigenclass : Class {
  const char* ruby_class_name() const override { return "SignalException"; }
};

struct Interrupt_eigenclass : Class {
  const char* ruby_class_name() const override { return "Interrupt"; }
};

struct SystemExit_eigenclass : Class {
  const char* ruby_class_name() const override { return "SystemExit"; }
};

struct StandardError_eigenclass : Class {
  const char* ruby_class_name() const override { return "StandardError"; }
};

struct RuntimeError_eigenclass : Class {
  const char* ruby_class_name() const override { return "RuntimeError"; }
};

struct FrozenError_eigenclass : Class {
  const char* ruby_class_name() const override { return "FrozenError"; }
};

struct NameError_eigenclass : Class {
  const char* ruby_class_name() const override { return "NameError"; }
};

struct NoMethodError_eigenclass : Class {
  const char* ruby_class_name() const override { return "NoMethodError"; }
};

struct TypeError_eigenclass : Class {
  const char* ruby_class_name() const override { return "TypeError"; }
};

struct ArgumentError_eigenclass : Class {
  const char* ruby_class_name() const override { return "ArgumentError"; }
};

struct RangeError_eigenclass : Class {
  const char* ruby_class_name() const override { return "RangeError"; }
};

struct FloatDomainError_eigenclass : Class {
  const char* ruby_class_name() const override { return "FloatDomainError"; }
};

struct ZeroDivisionError_eigenclass : Class {
  const char* ruby_class_name() const override { return "ZeroDivisionError"; }
};

struct IndexError_eigenclass : Class {
  const char* ruby_class_name() const override { return "IndexError"; }
};

struct FiberError_eigenclass : Class {
  const char* ruby_class_name() const override { return "FiberError"; }
};

struct ThreadError_eigenclass : Class {
  const char* ruby_class_name() const override { return "ThreadError"; }
};

struct NoMemoryError_eigenclass : Class {
  const char* ruby_class_name() const override { return "NoMemoryError"; }
};

struct SecurityError_eigenclass : Class {
  const char* ruby_class_name() const override { return "SecurityError"; }
};

struct SystemStackError_eigenclass : Class {
  const char* ruby_class_name() const override { return "SystemStackError"; }
};

struct NoMatchingPatternError_eigenclass : Class {
  const char* ruby_class_name() const override { return "NoMatchingPatternError"; }
};

struct KeyError_eigenclass : Class {
  const char* ruby_class_name() const override { return "KeyError"; }
};

struct StopIteration_eigenclass : Class {
  const char* ruby_class_name() const override { return "StopIteration"; }
};

struct ClosedQueueError_eigenclass : Class {
  const char* ruby_class_name() const override { return "ClosedQueueError"; }
};

struct UncaughtThrowError_eigenclass : Class {
  const char* ruby_class_name() const override { return "UncaughtThrowError"; }
};

struct LocalJumpError_eigenclass : Class {
  const char* ruby_class_name() const override { return "LocalJumpError"; }
};

struct SystemCallError_eigenclass : Class {
  const char* ruby_class_name() const override { return "SystemCallError"; }
};

struct IOError_eigenclass : Class {
  const char* ruby_class_name() const override { return "IOError"; }
};

struct EOFError_eigenclass : Class {
  const char* ruby_class_name() const override { return "EOFError"; }
};

struct EncodingError_eigenclass : Class {
  const char* ruby_class_name() const override { return "EncodingError"; }
};

struct RegexpError_eigenclass : Class {
  const char* ruby_class_name() const override { return "RegexpError"; }
};

struct Encoding_eigenclass : Class {
  const char* ruby_class_name() const override { return "Encoding"; }
};

struct MatchData_eigenclass : Class {
  const char* ruby_class_name() const override { return "MatchData"; }
};

struct Regexp_eigenclass : Class {
  const char* ruby_class_name() const override { return "Regexp"; }
};

struct Rational_eigenclass : Class {
  const char* ruby_class_name() const override { return "Rational"; }
};

struct Complex_eigenclass : Class {
  const char* ruby_class_name() const override { return "Complex"; }
};

struct IO_eigenclass : Class {
  const char* ruby_class_name() const override { return "IO"; }
};

struct File_eigenclass : Class {
  const char* ruby_class_name() const override { return "File"; }
};

struct Dir_eigenclass : Class {
  const char* ruby_class_name() const override { return "Dir"; }
};

struct Time_eigenclass : Class {
  const char* ruby_class_name() const override { return "Time"; }
};

struct Mutex_eigenclass : Class {
  const char* ruby_class_name() const override { return "Mutex"; }
};

struct Fiber_eigenclass : Class {
  const char* ruby_class_name() const override { return "Fiber"; }
};

struct ThreadKill_eigenclass : Class {
  const char* ruby_class_name() const override { return "ThreadKill"; }
};

struct Thread_eigenclass : Class {
  const char* ruby_class_name() const override { return "Thread"; }
};

struct ThreadGroup_eigenclass : Class {
  const char* ruby_class_name() const override { return "ThreadGroup"; }
};

struct ConditionVariable_eigenclass : Class {
  const char* ruby_class_name() const override { return "ConditionVariable"; }
};

struct Queue_eigenclass : Class {
  const char* ruby_class_name() const override { return "Queue"; }
};

struct SizedQueue_eigenclass : Class {
  const char* ruby_class_name() const override { return "SizedQueue"; }
};

struct Process_eigenclass : Class {
  const char* ruby_class_name() const override { return "Process"; }
};

struct Binding_eigenclass : Class {
  const char* ruby_class_name() const override { return "Binding"; }
};

struct PP_eigenclass : Class {
  const char* ruby_class_name() const override { return "PP"; }
};

struct StringIO_eigenclass : Class {
  const char* ruby_class_name() const override { return "StringIO"; }
};

struct Struct_eigenclass : Class {
  const char* ruby_class_name() const override { return "Struct"; }
};

struct Data_eigenclass : Class {
  const char* ruby_class_name() const override { return "Data"; }
};

struct Set_eigenclass : Class {
  const char* ruby_class_name() const override { return "Set"; }
};

struct Random_eigenclass : Class {
  const char* ruby_class_name() const override { return "Random"; }
};

struct ENVClass_eigenclass : Class {
  const char* ruby_class_name() const override { return "ENVClass"; }
};

struct Counter_eigenclass : Class {
  const char* ruby_class_name() const override { return "Counter"; }
  BasicObject* m_create_with(BasicObject* n) override {
    return (new Counter(n));
    return nil_instance();
  }
  BasicObject* m_zero() override {
    return (new Counter((new Integer(0LL))));
    return nil_instance();
  }
};

inline NilClass NIL_INSTANCE;
inline TrueClass TRUE_INSTANCE;
inline FalseClass FALSE_INSTANCE;
inline BasicObject_eigenclass BasicObject_CLASS;
inline Object_eigenclass Object_CLASS;
inline NilClass_eigenclass NilClass_CLASS;
inline TrueClass_eigenclass TrueClass_CLASS;
inline FalseClass_eigenclass FalseClass_CLASS;
inline Integer_eigenclass Integer_CLASS;
inline Float_eigenclass Float_CLASS;
inline Array_eigenclass Array_CLASS;
inline Symbol_eigenclass Symbol_CLASS;
inline String_eigenclass String_CLASS;
inline Hash_eigenclass Hash_CLASS;
inline Module_eigenclass Module_CLASS;
inline Numeric_eigenclass Numeric_CLASS;
inline Refinement_eigenclass Refinement_CLASS;
inline Proc_eigenclass Proc_CLASS;
inline Method_eigenclass Method_CLASS;
inline UnboundMethod_eigenclass UnboundMethod_CLASS;
inline Range_eigenclass Range_CLASS;
inline Enumerator_eigenclass Enumerator_CLASS;
inline Exception_eigenclass Exception_CLASS;
inline ScriptError_eigenclass ScriptError_CLASS;
inline LoadError_eigenclass LoadError_CLASS;
inline SyntaxError_eigenclass SyntaxError_CLASS;
inline NotImplementedError_eigenclass NotImplementedError_CLASS;
inline SignalException_eigenclass SignalException_CLASS;
inline Interrupt_eigenclass Interrupt_CLASS;
inline SystemExit_eigenclass SystemExit_CLASS;
inline StandardError_eigenclass StandardError_CLASS;
inline RuntimeError_eigenclass RuntimeError_CLASS;
inline FrozenError_eigenclass FrozenError_CLASS;
inline NameError_eigenclass NameError_CLASS;
inline NoMethodError_eigenclass NoMethodError_CLASS;
inline TypeError_eigenclass TypeError_CLASS;
inline ArgumentError_eigenclass ArgumentError_CLASS;
inline RangeError_eigenclass RangeError_CLASS;
inline FloatDomainError_eigenclass FloatDomainError_CLASS;
inline ZeroDivisionError_eigenclass ZeroDivisionError_CLASS;
inline IndexError_eigenclass IndexError_CLASS;
inline FiberError_eigenclass FiberError_CLASS;
inline ThreadError_eigenclass ThreadError_CLASS;
inline NoMemoryError_eigenclass NoMemoryError_CLASS;
inline SecurityError_eigenclass SecurityError_CLASS;
inline SystemStackError_eigenclass SystemStackError_CLASS;
inline NoMatchingPatternError_eigenclass NoMatchingPatternError_CLASS;
inline KeyError_eigenclass KeyError_CLASS;
inline StopIteration_eigenclass StopIteration_CLASS;
inline ClosedQueueError_eigenclass ClosedQueueError_CLASS;
inline UncaughtThrowError_eigenclass UncaughtThrowError_CLASS;
inline LocalJumpError_eigenclass LocalJumpError_CLASS;
inline SystemCallError_eigenclass SystemCallError_CLASS;
inline IOError_eigenclass IOError_CLASS;
inline EOFError_eigenclass EOFError_CLASS;
inline EncodingError_eigenclass EncodingError_CLASS;
inline RegexpError_eigenclass RegexpError_CLASS;
inline Encoding_eigenclass Encoding_CLASS;
inline MatchData_eigenclass MatchData_CLASS;
inline Regexp_eigenclass Regexp_CLASS;
inline Rational_eigenclass Rational_CLASS;
inline Complex_eigenclass Complex_CLASS;
inline IO_eigenclass IO_CLASS;
inline File_eigenclass File_CLASS;
inline Dir_eigenclass Dir_CLASS;
inline Time_eigenclass Time_CLASS;
inline Mutex_eigenclass Mutex_CLASS;
inline Fiber_eigenclass Fiber_CLASS;
inline ThreadKill_eigenclass ThreadKill_CLASS;
inline Thread_eigenclass Thread_CLASS;
inline ThreadGroup_eigenclass ThreadGroup_CLASS;
inline ConditionVariable_eigenclass ConditionVariable_CLASS;
inline Queue_eigenclass Queue_CLASS;
inline SizedQueue_eigenclass SizedQueue_CLASS;
inline Process_eigenclass Process_CLASS;
inline Binding_eigenclass Binding_CLASS;
inline PP_eigenclass PP_CLASS;
inline StringIO_eigenclass StringIO_CLASS;
inline Struct_eigenclass Struct_CLASS;
inline Data_eigenclass Data_CLASS;
inline Set_eigenclass Set_CLASS;
inline Random_eigenclass Random_CLASS;
inline ENVClass_eigenclass ENVClass_CLASS;
inline Counter_eigenclass Counter_CLASS;

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
  if (auto* f = dynamic_cast<Float*>(o))        { std::printf("%g\n", f->raw_); return; }
  if (auto* s = dynamic_cast<Symbol*>(o))       { std::printf("%s\n", s->name_); return; }
  if (auto* str = dynamic_cast<String*>(o))     { std::fwrite(str->bytes.data(), 1, str->bytes.size(), stdout); std::putchar('\n'); return; }
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
    BasicObject* c1 = (&Counter_CLASS)->m_create_with((new Integer(42LL)));
    ruby_puts(c1->m_value());
    BasicObject* c2 = (&Counter_CLASS)->m_zero();
    ruby_puts(c2->m_value());
    BasicObject* klass = (&Counter_CLASS);
    BasicObject* c3 = klass->m_create_with((new Integer(99LL)));
    ruby_puts(c3->m_value());
  }
};

}  // namespace Ruby

int main() {
  FROZONE_GC_INIT();
  Ruby::MainObject mo;
  mo.__top_level__();
  return 0;
}
