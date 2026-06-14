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


struct Ruby_SplayTree {
  int64_t root = 0;

  int64_t empty?() {
    return root.nil?();
  }

  int64_t insert(int64_t key, int64_t value) {
    if (empty?()) {
      root = Node.new(key, value); return;
    }
    splay!(key);
    if ((root.key() == key)) {
      return;
    }
    int64_t node = Node.new(key, value);
    if ((key > root.key())) {
      node.left=(root); node.right=(root.right()); root.right=(RUBY_NIL);
    } else {
      node.right=(root); node.left=(root.left()); root.left=(RUBY_NIL);
    }
    return root = node;
  }

  int64_t remove(int64_t key) {
    if (empty?()) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
    splay!(key);
    if ((root.key() != key)) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
    int64_t removed = root;
    if (root.left().nil?()) {
      root = root.right();
    } else {
      int64_t right = root.right(); root = root.left(); splay!(key); root.right=(right);
    }
    return removed;
  }

  int64_t find(int64_t key) {
    if (empty?()) {
      return RUBY_NIL;
    }
    splay!(key);
    if ((root.key() == key)) {
      root;
    } else {
      RUBY_NIL;
    }
  }

  int64_t find_max() {
    if (empty?()) {
      return RUBY_NIL;
    }
    int64_t current = (start_node || root);
    while (current.right()) {
      current = current.right();
    }
    return current;
  }

  int64_t find_greatest_less_than(int64_t key) {
    if (empty?()) {
      return RUBY_NIL;
    }
    splay!(key);
    if ((root.key() < key)) {
      root;
    } else {
      if (root.left()) {
        find_max(root.left());
      };
    }
  }

  int64_t splay!(int64_t key) {
    if (empty?()) {
      return;
    }
    int64_t dummy = Node.new(RUBY_NIL, RUBY_NIL);
    int64_t left = dummy;
    int64_t right = dummy;
    int64_t current = root;
    loop();
    left.right=(current.left());
    right.left=(current.right());
    current.left=(dummy.right());
    current.right=(dummy.left());
    return root = current;
  }

  int64_t generate_payload(int64_t depth, int64_t tag) {
    if ((depth == 0LL)) {
      /* UNSUPPORTED: HashLiteral */;
    } else {
      PayloadNode.new(generate_payload((depth - 1LL), tag), generate_payload((depth - 1LL), tag));
    }
  }

  int64_t insert_new_node(int64_t tree, int64_t rng) {
    return loop();
  }

  int64_t splay_setup(int64_t rng) {
    int64_t tree = SplayTree.new();
    for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
      insert_new_node(tree, rng);
    }
    return tree;
  }

  int64_t splay_run(int64_t tree, int64_t rng) {
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
    root = RUBY_NIL;
  }
};

struct Ruby_PayloadNode {
  int64_t left = 0;
  int64_t right = 0;

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

  int64_t generate_payload(int64_t depth, int64_t tag) {
    if ((depth == 0LL)) {
      /* UNSUPPORTED: HashLiteral */;
    } else {
      PayloadNode.new(generate_payload((depth - 1LL), tag), generate_payload((depth - 1LL), tag));
    }
  }

  int64_t insert_new_node(int64_t tree, int64_t rng) {
    return loop();
  }

  int64_t splay_setup(int64_t rng) {
    int64_t tree = SplayTree.new();
    for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
      insert_new_node(tree, rng);
    }
    return tree;
  }

  int64_t splay_run(int64_t tree, int64_t rng) {
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
    left = left;
    right = right;
  }
};


static const int64_t TREE_SIZE = 8000LL;
static const int64_t MODIFICATIONS = 80LL;
static const int64_t PAYLOAD_DEPTH = 5LL;

static int64_t generate_payload(int64_t depth, int64_t tag) {
  if ((depth == 0LL)) {
    /* UNSUPPORTED: HashLiteral */;
  } else {
    PayloadNode.new(generate_payload((depth - 1LL), tag), generate_payload((depth - 1LL), tag));
  }
}

static int64_t insert_new_node(int64_t tree, int64_t rng) {
  return loop();
}

static int64_t splay_setup(int64_t rng) {
  int64_t tree = SplayTree.new();
  for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
    insert_new_node(tree, rng);
  }
  return tree;
}

static int64_t splay_run(int64_t tree, int64_t rng) {
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
  int64_t rng = Random.new(42LL);
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
