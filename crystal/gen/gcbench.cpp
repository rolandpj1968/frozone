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


struct Ruby_GCNode {
  int64_t left = 0;
  int64_t right = 0;
  int64_t i = 0;
  int64_t j = 0;

  int64_t left() {
    return left;
  }

  int64_t left=(int64_t __anon_req__) {
    return left = __anon_req__;
  }

  int64_t right() {
    return right;
  }

  int64_t right=(int64_t __anon_req__) {
    return right = __anon_req__;
  }

  int64_t i() {
    return i;
  }

  int64_t i=(int64_t __anon_req__) {
    return i = __anon_req__;
  }

  int64_t j() {
    return j;
  }

  int64_t j=(int64_t __anon_req__) {
    return j = __anon_req__;
  }

  int64_t gc_tree_size(int64_t depth) {
    return ((1LL << (depth + 1LL)) - 1LL);
  }

  int64_t gc_num_iters(int64_t depth) {
    return ((2LL * gc_tree_size(STRETCH_TREE_DEPTH)) / gc_tree_size(depth));
  }

  int64_t gc_populate(int64_t depth, int64_t node) {
    if ((depth > 0LL)) {
      depth = (depth - 1LL); left = GCNode.new(); right = GCNode.new(); node.left=(left); node.right=(right); gc_populate(depth, left); gc_populate(depth, right);
    }
  }

  int64_t gc_make_tree(int64_t depth) {
    if ((depth <= 0LL)) {
      GCNode.new();
    } else {
      GCNode.new(gc_make_tree((depth - 1LL)), gc_make_tree((depth - 1LL)));
    }
  }

  int64_t gc_time_construction(int64_t depth) {
    int64_t n = gc_num_iters(depth);
    for (int64_t _i = 0; _i < n; _i++) {
      int64_t node = GCNode.new();
      gc_populate(depth, node);
    }
    for (int64_t _i = 0; _i < n; _i++) {
      gc_make_tree(depth);
    }
  }

  Ruby_GCNode() {
    left = left;
    right = right;
    i = 0LL;
    j = 0LL;
  }
};


static const int64_t STRETCH_TREE_DEPTH = 18LL;
static const int64_t LONG_LIVED_TREE_DEPTH = 16LL;
static const int64_t MIN_TREE_DEPTH = 4LL;
static const int64_t MAX_TREE_DEPTH = 16LL;

static int64_t gc_tree_size(int64_t depth) {
  return ((1LL << (depth + 1LL)) - 1LL);
}

static int64_t gc_num_iters(int64_t depth) {
  return ((2LL * gc_tree_size(STRETCH_TREE_DEPTH)) / gc_tree_size(depth));
}

static int64_t gc_populate(int64_t depth, int64_t node) {
  if ((depth > 0LL)) {
    depth = (depth - 1LL); left = GCNode.new(); right = GCNode.new(); node.left=(left); node.right=(right); gc_populate(depth, left); gc_populate(depth, right);
  }
}

static int64_t gc_make_tree(int64_t depth) {
  if ((depth <= 0LL)) {
    GCNode.new();
  } else {
    GCNode.new(gc_make_tree((depth - 1LL)), gc_make_tree((depth - 1LL)));
  }
}

static int64_t gc_time_construction(int64_t depth) {
  int64_t n = gc_num_iters(depth);
  for (int64_t _i = 0; _i < n; _i++) {
    int64_t node = GCNode.new();
    gc_populate(depth, node);
  }
  for (int64_t _i = 0; _i < n; _i++) {
    gc_make_tree(depth);
  }
}


int main() {
  gc_make_tree(STRETCH_TREE_DEPTH);
  int64_t long_lived_tree = GCNode.new();
  gc_populate(LONG_LIVED_TREE_DEPTH, long_lived_tree);
  for (int64_t _i = 0; _i < 10LL; _i++) {
    /* UNSUPPORTED: ConstantPath */.step(/* UNSUPPORTED: ConstantPath */, 2LL);
  }
  return 0;
}
