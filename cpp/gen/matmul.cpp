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



static const int64_t N = 200LL;

static int64_t make_shareable(auto x) {
  return x;
}

static auto matgen(auto n) {
  int64_t tmp = ((1.0 / n) / n);
  return ({ auto _arr = RubyArray_F64(n); for (int64_t i = 0; i < n; i++) { _arr[i] = ({ auto _arr = RubyArray_F64(n); for (int64_t j = 0; j < n; j++) { _arr[j] = ((tmp * (i - j)) * (i + j)); } _arr; }); } _arr; });
}

static int64_t matmul(auto a, auto b) {
  int64_t m = a.len;
  int64_t n = a[0LL].len;
  int64_t p = b[0LL].len;
  RubyArray_I64 c = ({ auto _arr = RubyArray_F64(m); for (int64_t _ai = 0; _ai < m; _ai++) { _arr[_ai] = RubyArray_I64(p, 0.0); } _arr; });
  for (int64_t i = 0; i < m; i++) {
    int64_t ci = c[i];
    int64_t ai = a[i];
    int64_t k = 0LL;
    while ((k < n)) {
    int64_t aik = ai[k];
    int64_t bk = b[k];
    int64_t j = 0LL;
    while ((j < p)) {
    ci[j] += (aik * bk[j]);
    j = (j + 1LL);
  };
    k = (k + 1LL);
  };
  }
  return c;
}


int main() {
  int64_t last = 0.0;
  for (int64_t _i = 0; _i < 20LL; _i++) {
    int64_t a = matgen(N);
    int64_t b = matgen(N);
    int64_t c = matmul(a, b);
    last = c[(N / 2LL)][(N / 2LL)];
  }
  printf("%lld\n", (long long)(last));
  return 0;
}
