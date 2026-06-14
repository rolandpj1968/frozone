#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>

// --- Frozone C++ runtime (minimal) ---

class RubyObject {
public:
  virtual ~RubyObject() = default;
  virtual int64_t to_i64() { return 0; }
  virtual double to_f64() { return 0.0; }
  virtual const char* to_s() { return "#<Object>"; }
  virtual bool truthy() { return true; }
};

class RubyNil : public RubyObject {
public:
  bool truthy() override { return false; }
  const char* to_s() override { return ""; }
};

class RubyInteger : public RubyObject {
public:
  int64_t value;
  RubyInteger(int64_t v) : value(v) {}
  int64_t to_i64() override { return value; }
  const char* to_s() override {
    static thread_local char buf[32];
    snprintf(buf, sizeof(buf), "%lld", (long long)value);
    return buf;
  }
};

class RubyFloat : public RubyObject {
public:
  double value;
  RubyFloat(double v) : value(v) {}
  double to_f64() override { return value; }
  int64_t to_i64() override { return (int64_t)value; }
};

// Native Int64 array — TI-specialised, no boxing
class RubyArray_I64 {
public:
  int64_t* data;
  int64_t len;
  RubyArray_I64(int64_t size, int64_t fill = 0) : len(size) {
    data = (int64_t*)calloc(size, sizeof(int64_t));
    if (fill) for (int64_t i = 0; i < size; i++) data[i] = fill;
  }
  int64_t& operator[](int64_t i) { return data[i]; }
  ~RubyArray_I64() { free(data); }
};

// Native Float64 array
class RubyArray_F64 {
public:
  double* data;
  int64_t len;
  RubyArray_F64(int64_t size = 0, double fill = 0.0) : len(size) {
    data = (double*)calloc(size > 0 ? size : 1, sizeof(double));
    if (fill != 0.0) for (int64_t i = 0; i < size; i++) data[i] = fill;
  }
  double& operator[](int64_t i) { return data[i]; }
  ~RubyArray_F64() { free(data); }
};

static RubyNil RUBY_NIL_INSTANCE;
static RubyObject* RUBY_NIL = &RUBY_NIL_INSTANCE;


struct Ruby_A {
  Ruby_A() {
    RUBY_NIL;
  }
};




int main() {
  int64_t a = A.new();
  int64_t b = B.new();
  int64_t c = C.new();
  int64_t last = false;
  for (int64_t _i = 0; _i < 1000LL; _i++) {
    for (int64_t i = 0; i < 500000LL; i++) {
      a.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      a.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      a.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      a.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      b.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      b.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      b.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      b.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      c.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      c.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      c.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
      last = c.respond_to?(/* UNSUPPORTED: SymbolLiteral */);
    };
  }
  printf("%lld\n", (long long)(last));
  return 0;
}
