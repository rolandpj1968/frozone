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

// Mutable byte-oriented string. Encoding is tracked nominally
// but all methods operate on bytes (matches Ruby binary semantics).
#include <vector>
#include <cstring>
class RubyString {
public:
  std::vector<uint8_t> bytes;
  int64_t len = 0;
  RubyString() = default;
  RubyString(const char* s) { if (s) { size_t n = strlen(s); bytes.assign(s, s + n); len = n; } }
  RubyString(const char* s, size_t n) { bytes.assign(s, s + n); len = n; }
  int64_t bytesize() const { return len; }
  int64_t size() const { return len; }
  int64_t length() const { return len; }
  int64_t get_byte(int64_t i) const { return (i >= 0 && i < len) ? (int64_t)bytes[i] : 0; }
  void set_byte(int64_t i, int64_t v) { if (i >= 0 && i < len) bytes[i] = (uint8_t)(v & 0xff); }
  RubyString dup_() const { return *this; }
  RubyString& operator<<(const RubyString& o) {
    bytes.insert(bytes.end(), o.bytes.begin(), o.bytes.end()); len = (int64_t)bytes.size(); return *this;
  }
  RubyString& operator<<(const char* s) {
    if (s) { size_t n = strlen(s); bytes.insert(bytes.end(), s, s + n); len = (int64_t)bytes.size(); } return *this;
  }
  bool operator==(const RubyString& o) const { return bytes == o.bytes; }
  bool operator!=(const RubyString& o) const { return bytes != o.bytes; }
};
using Ruby_String = RubyString;

// Generic native array — TI-specialised per element type
// Uses shared_ptr so nested arrays / temporaries copy cheaply
#include <memory>
template<typename T> class RubyArray {
public:
  std::shared_ptr<T[]> data;
  int64_t len;
  RubyArray() : data(nullptr), len(0) {}
  RubyArray(int64_t size) : data(new T[size > 0 ? size : 1]()), len(size) {}
  RubyArray(int64_t size, T fill) : data(new T[size > 0 ? size : 1]), len(size) {
    for (int64_t i = 0; i < size; i++) data[i] = fill;
  }
  T& operator[](int64_t i) { return data[i]; }
  const T& operator[](int64_t i) const { return data[i]; }
};

using RubyArray_I64 = RubyArray<int64_t>;
using RubyArray_F64 = RubyArray<double>;
// Helper: deduce array element type from fill value
template<typename T> RubyArray<T> make_ra(int64_t n, T fill) { return RubyArray<T>(n, fill); }

static constexpr int64_t RUBY_NIL = 0;

// Ruby-flavored puts: chooses format based on type
#include <type_traits>
#include <charconv>
template<typename T> static inline void ruby_puts(T v) {
  if constexpr (std::is_same_v<T, bool>) {
    printf(v ? "true\n" : "false\n");
  } else if constexpr (std::is_floating_point_v<T>) {
    // Shortest round-trippable representation (matches Ruby's Float#to_s closely)
    char buf[64]; auto r = std::to_chars(buf, buf + sizeof(buf) - 4, (double)v);
    *r.ptr = 0;
    // Ensure trailing .0 for integer-valued doubles (Ruby convention)
    bool has_dot = false; for (char* p = buf; p < r.ptr; ++p) if (*p == '.' || *p == 'e' || *p == 'n' || *p == 'i') { has_dot = true; break; }
    if (!has_dot) { *r.ptr++ = '.'; *r.ptr++ = '0'; *r.ptr = 0; }
    printf("%s\n", buf);
  } else if constexpr (std::is_integral_v<T>) {
    printf("%lld\n", (long long)v);
  } else {
    printf("#<Object>\n");
  }
}
static inline void ruby_puts(const char* s) { printf("%s\n", s); }



static const int64_t MAX_DEPTH = 14LL;
static const int64_t MIN_DEPTH = 4LL;
static const int64_t STRETCH_DEPTH = 15LL;

static auto item_check(auto left, auto right) {
  if (left.nil_q()) {
    return INT64_C(1);
  }
  return ((INT64_C(1) + item_check(left[INT64_C(0)], left[INT64_C(1)])) + item_check(right[INT64_C(0)], right[INT64_C(1)]));
}

static auto bottom_up_tree(auto depth) {
  if (!((depth > INT64_C(0)))) {
    return ({ auto _e0 = RUBY_NIL; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = RUBY_NIL; _a; });
  }
  depth = (depth - INT64_C(1));
  return ({ auto _e0 = bottom_up_tree(depth); auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = bottom_up_tree(depth); _a; });
}


int main() {
  int64_t total = INT64_C(0);
  for (int64_t _i = 0; _i < INT64_C(60); _i++) {
    auto stretch_tree = bottom_up_tree(STRETCH_DEPTH);
    stretch_tree = RUBY_NIL;
    auto long_lived_tree = bottom_up_tree(MAX_DEPTH);
    auto depth = MIN_DEPTH;
    while ((depth <= MAX_DEPTH)) {
      auto iterations = INT64_C(2).**(((MAX_DEPTH - depth) + MIN_DEPTH));
      int64_t check = INT64_C(0);
      for (int64_t i = 0; i < (iterations + 1LL); i++) {
      auto temp_tree = bottom_up_tree(depth);
      check = (check + item_check(temp_tree[INT64_C(0)], temp_tree[INT64_C(1)]));
    };
      total = (total + check);
      depth = (depth + INT64_C(2));
    };
  }
  ruby_puts(total);
  return 0;
}
