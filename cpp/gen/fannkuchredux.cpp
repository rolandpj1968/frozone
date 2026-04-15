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



static const int64_t N = 9LL;

static int64_t fannkuch(auto n) {
  int64_t p = (n + 1LL).to_a();
  int64_t s = p;
  int64_t q = p;
  int64_t sign = 1LL;
  int64_t sum = int64_t maxflips = 0LL;
  while (true) {
    if ((q1 = p[1LL] != 1LL)) {
    q[(-1LL + 1LL)] = p; flips = 1LL; while (!((qq = q[q1] == 1LL))) {
      q[q1] = q1;
      if ((q1 >= 4LL)) {
      i = 2LL; j = (q1 - 1LL); while ((i < j)) {
        local(q, 0) = q[j]; local(q, 0) = q[i];
        i = (i + 1LL);
        j = (j - 1LL);
      };
    };
      q1 = qq;
      flips = (flips + 1LL);
    }; sum = (sum + (sign * flips)); if ((flips > maxflips)) {
      maxflips = flips;
    };
  };
    if ((sign == 1LL)) {
    local(p, 0) = p[2LL]; local(p, 0) = p[1LL]; sign = -1LL;
  } else {
    local(p, 0) = p[3LL]; local(p, 0) = p[2LL]; sign = 1LL; i = 3LL; while (((i <= n) && (s[i] == 1LL))) {
      if ((i == n)) {
      return ({ auto _a = RubyArray_I64(2); _a[0] = sum; _a[1] = maxflips; _a; });
    };
      s[i] = i;
      t = p.delete_at(1LL);
      i = (i + 1LL);
      p.insert(i, t);
    }; if ((i <= n)) {
      s[i] -= 1LL;
    };
  };
  }
}


int main() {
  int64_t last = 0LL;
  for (int64_t _i = 0; _i < 10LL; _i++) {
    last = fannkuch(N);
  }
  printf("%lld\n", (long long)(last));
  return 0;
}
