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

static constexpr int64_t RUBY_NIL = 0;




static int64_t nq_solve(auto n) {
  RubyArray_I64 a = RubyArray_I64(n, -1LL);
  RubyArray_I64 l = RubyArray_I64(n, 0LL);
  RubyArray_I64 c = RubyArray_I64(n, 0LL);
  RubyArray_I64 r = RubyArray_I64(n, 0LL);
  int64_t y0 = ((1LL << n) - 1LL);
  int64_t m = 0LL;
  int64_t k = 0LL;
  while ((k >= 0LL)) {
    int64_t y = (((l[k] | c[k]) | r[k]) & y0);
    if ((((y ^ y0) >> (a[k] + 1LL)) != 0LL)) {
    int64_t i = (a[k] + 1LL); while (((i < n) && ((y & (1LL << i)) != 0LL))) {
      i = (i + 1LL);
    }; if ((k < (n - 1LL))) {
      int64_t z = (1LL << i); a[k] = i; k = (k + 1LL); l[k] = ((l[(k - 1LL)] | z) << 1LL); c[k] = (c[(k - 1LL)] | z); r[k] = ((r[(k - 1LL)] | z) >> 1LL);
    } else {
      m = (m + 1LL); k = (k - 1LL);
    };
  } else {
    a[k] = -1LL; k = (k - 1LL);
  };
  }
  return m;
}


int main() {
  int64_t last = 0LL;
  for (int64_t _i = 0; _i < 3LL; _i++) {
    last = nq_solve(8LL);
  }
  printf("%lld\n", (long long)(last));
  return 0;
}
