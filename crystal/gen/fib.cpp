#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>

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

static RubyNil RUBY_NIL_INSTANCE;
static RubyObject* RUBY_NIL = &RUBY_NIL_INSTANCE;

static int64_t run_benchmark() {
  RUBY_NIL;
}

static int64_t fib(int64_t n) {
  if ((n < 2LL)) {
    return n;
  }
  return (fib((n - 1LL)) + fib((n - 2LL)));
}


int main() {
  int64_t total = 0LL;
  for (int64_t _i = 0; _i < 3LL; _i++) {
    total = (total + fib(35LL));
  }
  printf("%lld\n", (long long)(total));
  return 0;
}
