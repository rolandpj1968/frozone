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



static const int64_t MAX_DEPTH = 14LL;
static const int64_t MIN_DEPTH = 4LL;
static const int64_t STRETCH_DEPTH = 15LL;

static int64_t item_check(int64_t left, int64_t right) {
  if (left.nil?()) {
    return 1LL;
  }
  return ((1LL + item_check(left[0LL], left[1LL])) + item_check(right[0LL], right[1LL]));
}

static int64_t bottom_up_tree(int64_t depth) {
  if (!((depth > 0LL))) {
    return /* UNSUPPORTED: ArrayLiteral */;
  }
  depth = (depth - 1LL);
  return /* UNSUPPORTED: ArrayLiteral */;
}


int main() {
  int64_t total = 0LL;
  for (int64_t _i = 0; _i < 60LL; _i++) {
    int64_t stretch_tree = bottom_up_tree(STRETCH_DEPTH);
    stretch_tree = RUBY_NIL;
    int64_t long_lived_tree = bottom_up_tree(MAX_DEPTH);
    int64_t depth = MIN_DEPTH;
    while ((depth <= MAX_DEPTH)) {
      int64_t iterations = 2LL.**(((MAX_DEPTH - depth) + MIN_DEPTH));
      int64_t check = 0LL;
      for (int64_t i = 0; i < (iterations + 1LL); i++) {
      int64_t temp_tree = bottom_up_tree(depth);
      check = (check + item_check(temp_tree[0LL], temp_tree[1LL]));
    };
      total = (total + check);
      depth = (depth + 2LL);
    };
  }
  printf("%lld\n", (long long)(total));
  return 0;
}
