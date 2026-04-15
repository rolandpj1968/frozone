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


struct Ruby_SplayTree {
  int64_t iv_root = 0;

  int64_t empty_q() {
    return iv_root.nil_q();
  }

  int64_t insert(auto key, auto value) {
    if (empty_q()) {
      iv_root = Ruby_Node(key, value); return;
    }
    splay_b(key);
    if ((iv_root.key() == key)) {
      return;
    }
    Ruby_Node node = Ruby_Node(key, value);
    if ((key > iv_root.key())) {
      node.set_left(iv_root); node.set_right(iv_root.right()); iv_root.set_right(RUBY_NIL);
    } else {
      node.set_right(iv_root); node.set_left(iv_root.left()); iv_root.set_left(RUBY_NIL);
    }
    return iv_root = node;
  }

  int64_t remove(auto key) {
    if (empty_q()) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
    splay_b(key);
    if ((iv_root.key() != key)) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
    int64_t removed = iv_root;
    if (iv_root.left().nil_q()) {
      iv_root = iv_root.right();
    } else {
      int64_t right = iv_root.right(); iv_root = iv_root.left(); splay_b(key); iv_root.set_right(right);
    }
    return removed;
  }

  int64_t find(auto key) {
    if (empty_q()) {
      return RUBY_NIL;
    }
    splay_b(key);
    if ((iv_root.key() == key)) {
      iv_root;
    } else {
      RUBY_NIL;
    }
  }

  int64_t find_max() {
    if (empty_q()) {
      return RUBY_NIL;
    }
    int64_t current = (start_node || iv_root);
    while (current.right()) {
      current = current.right();
    }
    return current;
  }

  int64_t find_greatest_less_than(auto key) {
    if (empty_q()) {
      return RUBY_NIL;
    }
    splay_b(key);
    if ((iv_root.key() < key)) {
      iv_root;
    } else {
      if (iv_root.left()) {
        find_max(iv_root.left());
      };
    }
  }

  int64_t splay_b(auto key) {
    if (empty_q()) {
      return;
    }
    Ruby_Node dummy = Ruby_Node(RUBY_NIL, RUBY_NIL);
    int64_t left = dummy;
    int64_t right = dummy;
    int64_t current = iv_root;
    loop();
    left.set_right(current.left());
    right.set_left(current.right());
    current.set_left(dummy.right());
    current.set_right(dummy.left());
    return iv_root = current;
  }

  int64_t run_benchmark() {
    return 0LL;
  }

  int64_t generate_payload(auto depth, auto tag) {
    if ((depth == 0LL)) {
      /* UNSUPPORTED: HashLiteral */;
    } else {
      Ruby_PayloadNode(generate_payload((depth - 1LL), tag), generate_payload((depth - 1LL), tag));
    }
  }

  int64_t insert_new_node(auto tree, auto rng) {
    return loop();
  }

  int64_t splay_setup(auto rng) {
    Ruby_SplayTree tree = Ruby_SplayTree();
    for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
      insert_new_node(tree, rng);
    }
    return tree;
  }

  int64_t splay_run(auto tree, auto rng) {
    for (int64_t _i = 0; _i < MODIFICATIONS; _i++) {
      key = insert_new_node(tree, rng);
      greatest = tree.find_greatest_less_than(key);
      if (greatest) {
        tree.remove(greatest.key());
      } else {
        tree.remove(key);
      };
    }
  }

  Ruby_SplayTree() {
    iv_root = RUBY_NIL;
  }
};

struct Ruby_PayloadNode {
  int64_t iv_left = 0;
  int64_t iv_right = 0;

  int64_t left() {
    return iv_left;
  }

  int64_t set_left(auto __anon_req__) {
    iv_left = __anon_req__;
    return iv_left;
  }

  int64_t right() {
    return iv_right;
  }

  int64_t set_right(auto __anon_req__) {
    iv_right = __anon_req__;
    return iv_right;
  }

  int64_t run_benchmark() {
    return 0LL;
  }

  int64_t generate_payload(auto depth, auto tag) {
    if ((depth == 0LL)) {
      /* UNSUPPORTED: HashLiteral */;
    } else {
      Ruby_PayloadNode(generate_payload((depth - 1LL), tag), generate_payload((depth - 1LL), tag));
    }
  }

  int64_t insert_new_node(auto tree, auto rng) {
    return loop();
  }

  int64_t splay_setup(auto rng) {
    Ruby_SplayTree tree = Ruby_SplayTree();
    for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
      insert_new_node(tree, rng);
    }
    return tree;
  }

  int64_t splay_run(auto tree, auto rng) {
    for (int64_t _i = 0; _i < MODIFICATIONS; _i++) {
      key = insert_new_node(tree, rng);
      greatest = tree.find_greatest_less_than(key);
      if (greatest) {
        tree.remove(greatest.key());
      } else {
        tree.remove(key);
      };
    }
  }

  Ruby_PayloadNode(int64_t left, int64_t right) {
    iv_left = left;
    iv_right = right;
  }
};


static const int64_t TREE_SIZE = 8000LL;
static const int64_t MODIFICATIONS = 80LL;
static const int64_t PAYLOAD_DEPTH = 5LL;

static int64_t generate_payload(auto depth, auto tag) {
  if ((depth == 0LL)) {
    /* UNSUPPORTED: HashLiteral */;
  } else {
    Ruby_PayloadNode(generate_payload((depth - 1LL), tag), generate_payload((depth - 1LL), tag));
  }
}

static int64_t insert_new_node(auto tree, auto rng) {
  return loop();
}

static int64_t splay_setup(auto rng) {
  Ruby_SplayTree tree = Ruby_SplayTree();
  for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
    insert_new_node(tree, rng);
  }
  return tree;
}

static int64_t splay_run(auto tree, auto rng) {
  for (int64_t _i = 0; _i < MODIFICATIONS; _i++) {
    key = insert_new_node(tree, rng);
    greatest = tree.find_greatest_less_than(key);
    if (greatest) {
      tree.remove(greatest.key());
    } else {
      tree.remove(key);
    };
  }
}


int main() {
  Ruby_Random rng = Ruby_Random(42LL);
  int64_t tree = splay_setup(rng);
  for (int64_t _i = 0; _i < 200LL; _i++) {
    for (int64_t _i = 0; _i < 50LL; _i++) {
      splay_run(tree, rng);
    };
  }
  int64_t m = tree.find_max();
  printf("%.9f\n", (double)(m.key()));
  return 0;
}
