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


struct Ruby_TheClass {
  int64_t v0 = 0;
  int64_t v1 = 0;
  int64_t v2 = 0;
  int64_t levar = 0;

  int64_t v0() {
    return v0;
  }

  int64_t v0=(int64_t __anon_req__) {
    return v0 = __anon_req__;
  }

  int64_t v1() {
    return v1;
  }

  int64_t v1=(int64_t __anon_req__) {
    return v1 = __anon_req__;
  }

  int64_t v2() {
    return v2;
  }

  int64_t v2=(int64_t __anon_req__) {
    return v2 = __anon_req__;
  }

  int64_t levar() {
    return levar;
  }

  int64_t levar=(int64_t __anon_req__) {
    return levar = __anon_req__;
  }

  int64_t get_value_loop(int64_t obj) {
    int64_t sum = 0LL;
    int64_t i = 0LL;
    while ((i < 1000000LL)) {
      sum = (sum + obj.levar());
      sum = (sum + obj.levar());
      sum = (sum + obj.levar());
      sum = (sum + obj.levar());
      sum = (sum + obj.levar());
      sum = (sum + obj.levar());
      sum = (sum + obj.levar());
      sum = (sum + obj.levar());
      sum = (sum + obj.levar());
      sum = (sum + obj.levar());
      i = (i + 1LL);
    }
    return sum;
  }

  Ruby_TheClass(int64_t v0, int64_t v1, int64_t v2, int64_t levar) {
    v0 = v0;
    v1 = v1;
    v2 = v2;
    levar = levar;
  }
};



static int64_t get_value_loop(int64_t obj) {
  int64_t sum = 0LL;
  int64_t i = 0LL;
  while ((i < 1000000LL)) {
    sum = (sum + obj.levar());
    sum = (sum + obj.levar());
    sum = (sum + obj.levar());
    sum = (sum + obj.levar());
    sum = (sum + obj.levar());
    sum = (sum + obj.levar());
    sum = (sum + obj.levar());
    sum = (sum + obj.levar());
    sum = (sum + obj.levar());
    sum = (sum + obj.levar());
    i = (i + 1LL);
  }
  return sum;
}


int main() {
  int64_t obj = TheClass.new(1LL, 2LL, 3LL, 1LL);
  int64_t last = 0LL;
  for (int64_t _i = 0; _i < 850LL; _i++) {
    last = get_value_loop(obj);
  }
  printf("%lld\n", (long long)(last));
  return 0;
}
