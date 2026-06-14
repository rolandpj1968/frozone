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



static const char* A = "this is a long string with no useful contents yada yada yada yada";
static const char* B = "this is also a long string with no useful contents yada yada daaaaaa";

static int64_t ruby_xor!(int64_t a, int64_t b) {
  if ((a.is_a?(String).!() || b.is_a?(String).!())) {
    { fprintf(stderr, "Error: %s\n", "expected two string arguments"); exit(1); };
  }
  int64_t l = a.bytesize();
  int64_t lb = b.bytesize();
  if ((lb < l)) {
    l = lb;
  }
  int64_t i = 0LL;
  while ((i < l)) {
    int64_t ba = a.getbyte(i);
    int64_t bb = b.getbyte(i);
    a.setbyte(i, (ba ^ bb));
    i = i.succ();
  }
  return a;
}


int main() {
  int64_t a = A;
  int64_t b = B;
  int64_t sum = 0LL;
  for (int64_t _i = 0; _i < 2000LL; _i++) {
    int64_t result = ruby_xor!(a, b);
    sum = (sum + result.len);
  }
  printf("%lld\n", (long long)(sum));
  return 0;
}
