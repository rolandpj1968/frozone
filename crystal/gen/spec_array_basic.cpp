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


struct Ruby_SpecPositiveOperatorMatcher {
  int64_t actual = 0;

  int64_t ==(int64_t expected) {
    if (!((actual == expected))) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
    return true;
  }

  int64_t !=(int64_t expected) {
    if ((actual == expected)) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
    return true;
  }

  int64_t <(int64_t expected) {
    if (!((actual < expected))) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t <=(int64_t expected) {
    if (!((actual <= expected))) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t >(int64_t expected) {
    if (!((actual > expected))) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t >=(int64_t expected) {
    if (!((actual >= expected))) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t zero?() {
    if (!(actual.zero?())) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t nil?() {
    if (!(actual.nil?())) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t empty?() {
    if (!(actual.empty?())) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t frozen?() {
    if (!(actual.frozen?())) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t equal?(int64_t other) {
    if (!(actual.equal?(other))) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t describe(int64_t name) {
    return block.call();
  }

  int64_t it(int64_t name) {
    return block.call(); /* UNSUPPORTED: GlobalVariableWrite */;
  }

  int64_t context(int64_t name) {
    return describe(name);
  }

  int64_t should() {
    if (matcher) {
      if (!(matcher.matches?(/* UNSUPPORTED: SelfLiteral */))) {
        { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
      };
    } else {
      SpecPositiveOperatorMatcher.new(/* UNSUPPORTED: SelfLiteral */);
    }
  }

  int64_t should_not() {
    if (matcher) {
      if (matcher.matches?(/* UNSUPPORTED: SelfLiteral */)) {
        { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
      };
    } else {
      SpecNegativeOperatorMatcher.new(/* UNSUPPORTED: SelfLiteral */);
    }
  }

  int64_t ruby_version_is() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t platform_is() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t platform_is_not() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t guard(int64_t condition) {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t guard_not(int64_t condition) {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t with_feature() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t ruby_bug() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  Ruby_SpecPositiveOperatorMatcher(int64_t actual) {
    actual = actual;
  }
};

struct Ruby_SpecNegativeOperatorMatcher {
  int64_t actual = 0;

  int64_t ==(int64_t expected) {
    if ((actual == expected)) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
    return true;
  }

  int64_t zero?() {
    if (actual.zero?()) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t nil?() {
    if (actual.nil?()) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t empty?() {
    if (actual.empty?()) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
  }

  int64_t describe(int64_t name) {
    return block.call();
  }

  int64_t it(int64_t name) {
    return block.call(); /* UNSUPPORTED: GlobalVariableWrite */;
  }

  int64_t context(int64_t name) {
    return describe(name);
  }

  int64_t should() {
    if (matcher) {
      if (!(matcher.matches?(/* UNSUPPORTED: SelfLiteral */))) {
        { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
      };
    } else {
      SpecPositiveOperatorMatcher.new(/* UNSUPPORTED: SelfLiteral */);
    }
  }

  int64_t should_not() {
    if (matcher) {
      if (matcher.matches?(/* UNSUPPORTED: SelfLiteral */)) {
        { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
      };
    } else {
      SpecNegativeOperatorMatcher.new(/* UNSUPPORTED: SelfLiteral */);
    }
  }

  int64_t ruby_version_is() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t platform_is() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t platform_is_not() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t guard(int64_t condition) {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t guard_not(int64_t condition) {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t with_feature() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  int64_t ruby_bug() {
    if (block_given?()) {
      /* UNSUPPORTED: Yield */;
    }
  }

  Ruby_SpecNegativeOperatorMatcher(int64_t actual) {
    actual = actual;
  }
};


static const char* CODE_LOADING_DIR = ".";

static int64_t describe(int64_t name) {
  return block.call();
}

static int64_t it(int64_t name) {
  return block.call(); /* UNSUPPORTED: GlobalVariableWrite */;
}

static int64_t context(int64_t name) {
  return describe(name);
}

static int64_t should() {
  if (matcher) {
    if (!(matcher.matches?(/* UNSUPPORTED: SelfLiteral */))) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    };
  } else {
    SpecPositiveOperatorMatcher.new(/* UNSUPPORTED: SelfLiteral */);
  }
}

static int64_t should_not() {
  if (matcher) {
    if (matcher.matches?(/* UNSUPPORTED: SelfLiteral */)) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    };
  } else {
    SpecNegativeOperatorMatcher.new(/* UNSUPPORTED: SelfLiteral */);
  }
}

static int64_t ruby_version_is() {
  if (block_given?()) {
    /* UNSUPPORTED: Yield */;
  }
}

static int64_t platform_is() {
  if (block_given?()) {
    /* UNSUPPORTED: Yield */;
  }
}

static int64_t platform_is_not() {
  if (block_given?()) {
    /* UNSUPPORTED: Yield */;
  }
}

static int64_t guard(int64_t condition) {
  if (block_given?()) {
    /* UNSUPPORTED: Yield */;
  }
}

static int64_t guard_not(int64_t condition) {
  if (block_given?()) {
    /* UNSUPPORTED: Yield */;
  }
}

static int64_t with_feature() {
  if (block_given?()) {
    /* UNSUPPORTED: Yield */;
  }
}

static int64_t ruby_bug() {
  if (block_given?()) {
    /* UNSUPPORTED: Yield */;
  }
}


int main() {
  describe("Array");
  printf("%lld\n", (long long)(/* UNSUPPORTED: InterpolatedString */));
  if ((/* UNSUPPORTED: GlobalVariableRead */ > 0LL)) {
    { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
  }
  return 0;
}
