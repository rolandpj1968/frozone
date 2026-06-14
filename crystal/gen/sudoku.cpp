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



static Ruby_Array HARD20;

static int64_t make_shareable(int64_t x) {
  return x;
}

static int64_t sd_genmat() {
  RubyArray_I64 mr = ({ auto _arr = RubyArray_F64(324LL); for (int64_t _ai = 0; _ai < 324LL; _ai++) { _arr[_ai] = /* UNSUPPORTED: ArrayLiteral */; } _arr; });
  RubyArray_I64 mc = ({ auto _arr = RubyArray_F64(729LL); for (int64_t _ai = 0; _ai < 729LL; _ai++) { _arr[_ai] = RubyArray_I64(4LL, 0LL); } _arr; });
  int64_t r = 0LL;
  int64_t i = 0LL;
  while ((i < 9LL)) {
    int64_t j = 0LL;
    while ((j < 9LL)) {
    int64_t k = 0LL;
    while ((k < 9LL)) {
    int64_t mcr = mc[r];
    mcr[0LL] = ((9LL * i) + j);
    mcr[1LL] = ((((((i / 3LL) * 3LL) + (j / 3LL)) * 9LL) + k) + 81LL);
    mcr[2LL] = (((9LL * i) + k) + 162LL);
    mcr[3LL] = (((9LL * j) + k) + 243LL);
    r = (r + 1LL);
    k = (k + 1LL);
  };
    j = (j + 1LL);
  };
    i = (i + 1LL);
  }
  int64_t r2 = 0LL;
  while ((r2 < 729LL)) {
    int64_t c2 = 0LL;
    while ((c2 < 4LL)) {
    (mr[mc[r2][c2]] << r2);
    c2 = (c2 + 1LL);
  };
    r2 = (r2 + 1LL);
  }
  return /* UNSUPPORTED: ArrayLiteral */;
}

static int64_t sd_update_forward(int64_t mr, int64_t mc, int64_t sr, int64_t sc, int64_t r) {
  int64_t min = 10LL;
  int64_t min_c = 0LL;
  int64_t mcr = mc[r];
  int64_t c2 = 0LL;
  while ((c2 < 4LL)) {
    sc[mcr[c2]] += 128LL;
    c2 = (c2 + 1LL);
  }
  c2 = 0LL;
  while ((c2 < 4LL)) {
    int64_t mrc = mr[mcr[c2]];
    int64_t r2 = 0LL;
    while ((r2 < 9LL)) {
    int64_t rr = mrc[r2];
    if ((sr[rr] += 1LL == 1LL)) {
    int64_t p = mc[rr]; int64_t cc2 = 0LL; while ((cc2 < 4LL)) {
      int64_t cc = p[cc2];
      if ((sc[cc] -= 1LL < min)) {
      min = sc[cc]; min_c = cc;
    };
      cc2 = (cc2 + 1LL);
    };
  };
    r2 = (r2 + 1LL);
  };
    c2 = (c2 + 1LL);
  }
  return /* UNSUPPORTED: ArrayLiteral */;
}

static int64_t sd_update_reverse(int64_t mr, int64_t mc, int64_t sr, int64_t sc, int64_t r) {
  int64_t c2 = 0LL;
  while ((c2 < 4LL)) {
    sc[mc[r][c2]] -= 128LL;
    c2 = (c2 + 1LL);
  }
  c2 = 0LL;
  while ((c2 < 4LL)) {
    c = mc[r][c2];
    r2 = 0LL;
    while ((r2 < 9LL)) {
    rr = mr[c][r2];
    if ((sr[rr] -= 1LL == 0LL)) {
    p = mc[rr]; sc[p[0LL]] += 1LL; sc[p[1LL]] += 1LL; sc[p[2LL]] += 1LL; sc[p[3LL]] += 1LL;
  };
    r2 = (r2 + 1LL);
  };
    c2 = (c2 + 1LL);
  }
}

static int64_t sd_solve(int64_t mr, int64_t mc, int64_t s) {
  RubyArray_I64 sr = RubyArray_I64(729LL, 0LL);
  RubyArray_I64 sc = RubyArray_I64(324LL, 9LL);
  int64_t hints = 0LL;
  int64_t i = 0LL;
  while ((i < 81LL)) {
    int64_t char = s[i];
    int64_t a = if (((char >= "1") && (char <= "9"))) {
    (char.ord() - 49LL);
  } else {
    -1LL;
  };
    if ((a >= 0LL)) {
    sd_update_forward(mr, mc, sr, sc, ((i * 9LL) + a)); hints = (hints + 1LL);
  };
    i = (i + 1LL);
  }
  RubyArray_I64 cr = RubyArray_I64(81LL, -1LL);
  RubyArray_I64 cc = RubyArray_I64(81LL, 0LL);
  i = 0LL;
  int64_t min = 10LL;
  int64_t dir = 1LL;
  while (true) {
    while (((i >= 0LL) && (i < (81LL - hints)))) {
    if ((dir == 1LL)) {
    if ((min > 1LL)) {
      c = 0LL; while ((c < 324LL)) {
        if ((sc[c] < min)) {
        min = sc[c]; cc[i] = c; if ((min < 2LL)) {
          break;
        };
      };
        c = (c + 1LL);
      };
    }; if (((min == 0LL) || (min == 10LL))) {
      cr[i] = dir = -1LL; i = (i - 1LL);
    };
  };
    c = cc[i];
    if (((dir == -1LL) && (cr[i] >= 0LL))) {
    sd_update_reverse(mr, mc, sr, sc, mr[c][cr[i]]);
  };
    r2 = (cr[i] + 1LL);
    while (((r2 < 9LL) && (sr[mr[c][r2]] != 0LL))) {
    r2 = (r2 + 1LL);
  };
    if ((r2 < 9LL)) {
    /* UNSUPPORTED masgn */; cr[i] = r2; dir = 1LL; i = (i + 1LL);
  } else {
    cr[i] = -1LL; dir = -1LL; i = (i - 1LL);
  };
  };
    if ((i < 0LL)) {
    break;
  };
    o = RubyArray_I64(81LL, 0LL);
    j = 0LL;
    while ((j < 81LL)) {
    o[j] = (s[j].ord() - 48LL);
    j = (j + 1LL);
  };
    j = 0LL;
    while ((j < i)) {
    r = mr[cc[j]][cr[j]];
    o[(r / 9LL)] = ((r % 9LL) + 1LL);
    j = (j + 1LL);
  };
    o.join();
    i = (i - 1LL);
    dir = -1LL;
  }
}


int main() {
  /* UNSUPPORTED masgn */;
  int64_t last = "";
  for (int64_t _i = 0; _i < 20LL; _i++) {
    HARD20.each();
  }
  printf("%lld\n", (long long)(last));
  return 0;
}
