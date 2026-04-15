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




static auto make_shareable(auto x) {
  return x;
}

static auto sd_genmat() {
  auto mr = ({ auto _n = INT64_C(324); int64_t _ai = 0; auto _e0 = RubyArray_I64(0); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (_ai = 1; _ai < _n; _ai++) { _arr[_ai] = RubyArray_I64(0); } _arr; });
  auto mc = ({ auto _n = INT64_C(729); int64_t _ai = 0; auto _e0 = make_ra(INT64_C(4), INT64_C(0)); auto _arr = RubyArray<decltype(_e0)>(_n); _arr[0] = _e0; for (_ai = 1; _ai < _n; _ai++) { _arr[_ai] = make_ra(INT64_C(4), INT64_C(0)); } _arr; });
  int64_t r = INT64_C(0);
  int64_t i = INT64_C(0);
  while ((i < INT64_C(9))) {
    int64_t j = INT64_C(0);
    while ((j < INT64_C(9))) {
    int64_t k = INT64_C(0);
    while ((k < INT64_C(9))) {
    auto mcr = mc[r];
    mcr[INT64_C(0)] = ((INT64_C(9) * i) + j);
    mcr[INT64_C(1)] = ((((((i / INT64_C(3)) * INT64_C(3)) + (j / INT64_C(3))) * INT64_C(9)) + k) + INT64_C(81));
    mcr[INT64_C(2)] = (((INT64_C(9) * i) + k) + INT64_C(162));
    mcr[INT64_C(3)] = (((INT64_C(9) * j) + k) + INT64_C(243));
    r = (r + INT64_C(1));
    k = (k + INT64_C(1));
  };
    j = (j + INT64_C(1));
  };
    i = (i + INT64_C(1));
  }
  int64_t r2 = INT64_C(0);
  while ((r2 < INT64_C(729))) {
    int64_t c2 = INT64_C(0);
    while ((c2 < INT64_C(4))) {
    (mr[mc[r2][c2]] << r2);
    c2 = (c2 + INT64_C(1));
  };
    r2 = (r2 + INT64_C(1));
  }
  return ({ auto _e0 = mr; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = mc; _a; });
}

static auto sd_update_forward(auto mr, auto mc, auto sr, auto sc, auto r) {
  int64_t min = INT64_C(10);
  int64_t min_c = INT64_C(0);
  auto mcr = mc[r];
  int64_t c2 = INT64_C(0);
  while ((c2 < INT64_C(4))) {
    sc[mcr[c2]] += INT64_C(128);
    c2 = (c2 + INT64_C(1));
  }
  c2 = INT64_C(0);
  while ((c2 < INT64_C(4))) {
    auto mrc = mr[mcr[c2]];
    int64_t r2 = INT64_C(0);
    while ((r2 < INT64_C(9))) {
    auto rr = mrc[r2];
    if ((sr[rr] += INT64_C(1) == INT64_C(1))) {
    auto p = mc[rr]; int64_t cc2 = INT64_C(0); while ((cc2 < INT64_C(4))) {
      auto cc = p[cc2];
      if ((sc[cc] -= INT64_C(1) < min)) {
      min = sc[cc]; min_c = cc;
    };
      cc2 = (cc2 + INT64_C(1));
    };
  };
    r2 = (r2 + INT64_C(1));
  };
    c2 = (c2 + INT64_C(1));
  }
  return ({ auto _e0 = min; auto _a = RubyArray<decltype(_e0)>(2); _a[0] = _e0; _a[1] = min_c; _a; });
}

static auto sd_update_reverse(auto mr, auto mc, auto sr, auto sc, auto r) {
  int64_t c2 = INT64_C(0);
  while ((c2 < INT64_C(4))) {
    sc[mc[r][c2]] -= INT64_C(128);
    c2 = (c2 + INT64_C(1));
  }
  c2 = INT64_C(0);
  while ((c2 < INT64_C(4))) {
    c = mc[r][c2];
    r2 = INT64_C(0);
    while ((r2 < INT64_C(9))) {
    rr = mr[c][r2];
    if ((sr[rr] -= INT64_C(1) == INT64_C(0))) {
    p = mc[rr]; sc[p[INT64_C(0)]] += INT64_C(1); sc[p[INT64_C(1)]] += INT64_C(1); sc[p[INT64_C(2)]] += INT64_C(1); sc[p[INT64_C(3)]] += INT64_C(1);
  };
    r2 = (r2 + INT64_C(1));
  };
    c2 = (c2 + INT64_C(1));
  }
  return INT64_C(0);
}

static auto sd_solve(auto mr, auto mc, auto s) {
  auto sr = make_ra(INT64_C(729), INT64_C(0));
  auto sc = make_ra(INT64_C(324), INT64_C(9));
  int64_t hints = INT64_C(0);
  int64_t i = INT64_C(0);
  while ((i < INT64_C(81))) {
    auto char = s[i];
    int64_t a = if (((char >= RubyString("1", 1)) && (char <= RubyString("9", 1)))) {
    (char.ord() - INT64_C(49));
  } else {
    INT64_C(-1);
  };
    if ((a >= INT64_C(0))) {
    sd_update_forward(mr, mc, sr, sc, ((i * INT64_C(9)) + a)); hints = (hints + INT64_C(1));
  };
    i = (i + INT64_C(1));
  }
  auto cr = make_ra(INT64_C(81), INT64_C(-1));
  auto cc = make_ra(INT64_C(81), INT64_C(0));
  i = INT64_C(0);
  int64_t min = INT64_C(10);
  int64_t dir = INT64_C(1);
  while (true) {
    while (((i >= INT64_C(0)) && (i < (INT64_C(81) - hints)))) {
    if ((dir == INT64_C(1))) {
    if ((min > INT64_C(1))) {
      c = INT64_C(0); while ((c < INT64_C(324))) {
        if ((sc[c] < min)) {
        min = sc[c]; cc[i] = c; if ((min < INT64_C(2))) {
          break;
        };
      };
        c = (c + INT64_C(1));
      };
    }; if (((min == INT64_C(0)) || (min == INT64_C(10)))) {
      cr[i] = dir = INT64_C(-1); i = (i - INT64_C(1));
    };
  };
    c = cc[i];
    if (((dir == INT64_C(-1)) && (cr[i] >= INT64_C(0)))) {
    sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]]);
  };
    r2 = (cr[i] + INT64_C(1));
    while (((r2 < INT64_C(9)) && (sr[mr[c][r2]] != INT64_C(0)))) {
    r2 = (r2 + INT64_C(1));
  };
    if ((r2 < INT64_C(9))) {
    /* UNSUPPORTED masgn */; cr[i] = r2; dir = INT64_C(1); i = (i + INT64_C(1));
  } else {
    cr[i] = INT64_C(-1); dir = INT64_C(-1); i = (i - INT64_C(1));
  };
  };
    if ((i < INT64_C(0))) {
    break;
  };
    o = make_ra(INT64_C(81), INT64_C(0));
    j = INT64_C(0);
    while ((j < INT64_C(81))) {
    o[j] = (s[j].ord() - INT64_C(48));
    j = (j + INT64_C(1));
  };
    j = INT64_C(0);
    while ((j < i)) {
    r = mr[cc[j]][cr[j]];
    o[(r / INT64_C(9))] = ((r % INT64_C(9)) + INT64_C(1));
    j = (j + INT64_C(1));
  };
    o.join();
    i = (i - INT64_C(1));
    dir = INT64_C(-1);
  }
  return INT64_C(0);
}


int main() {
  /* UNSUPPORTED masgn */;
  RubyString last = RubyString("", 0);
  for (int64_t _i = 0; _i < INT64_C(20); _i++) {
    HARD20.each();
  }
  ruby_puts(last);
  return 0;
}
