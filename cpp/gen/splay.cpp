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


struct Ruby_SplayTree {
  int64_t iv_root = 0;

  auto empty_q() {
    return iv_root.nil_q();
  }

  auto insert(auto key, auto value) {
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

  auto remove(auto key) {
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
      auto right = iv_root.right(); iv_root = iv_root.left(); splay_b(key); iv_root.set_right(right);
    }
    return removed;
  }

  auto find(auto key) {
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

  auto find_max() {
    if (empty_q()) {
      return RUBY_NIL;
    }
    int64_t current = (start_node || iv_root);
    while (current.right()) {
      current = current.right();
    }
    return current;
  }

  auto find_greatest_less_than(auto key) {
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

  auto splay_b(auto key) {
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

  auto run_benchmark() {
    return 0LL;
  }

  auto generate_payload(auto depth, auto tag) {
    if ((depth == INT64_C(0))) {
      /* UNSUPPORTED: HashLiteral */;
    } else {
      Ruby_PayloadNode(generate_payload((depth - INT64_C(1)), tag), generate_payload((depth - INT64_C(1)), tag));
    }
  }

  auto insert_new_node(auto tree, auto rng) {
    return loop();
  }

  auto splay_setup(auto rng) {
    Ruby_SplayTree tree = Ruby_SplayTree();
    for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
      insert_new_node(tree, rng);
    }
    return tree;
  }

  auto splay_run(auto tree, auto rng) {
    for (int64_t _i = 0; _i < MODIFICATIONS; _i++) {
      key = insert_new_node(tree, rng);
      greatest = tree.find_greatest_less_than(key);
      if (greatest) {
        tree.remove(greatest.key());
      } else {
        tree.remove(key);
      };
    }
    return INT64_C(0);
  }

  Ruby_SplayTree() {
    iv_root = RUBY_NIL;
  }
};

struct Ruby_PayloadNode {
  int64_t iv_left = 0;
  int64_t iv_right = 0;

  auto left() {
    return iv_left;
  }

  auto set_left(auto __anon_req__) {
    iv_left = __anon_req__;
    return iv_left;
  }

  auto right() {
    return iv_right;
  }

  auto set_right(auto __anon_req__) {
    iv_right = __anon_req__;
    return iv_right;
  }

  auto run_benchmark() {
    return 0LL;
  }

  auto generate_payload(auto depth, auto tag) {
    if ((depth == INT64_C(0))) {
      /* UNSUPPORTED: HashLiteral */;
    } else {
      Ruby_PayloadNode(generate_payload((depth - INT64_C(1)), tag), generate_payload((depth - INT64_C(1)), tag));
    }
  }

  auto insert_new_node(auto tree, auto rng) {
    return loop();
  }

  auto splay_setup(auto rng) {
    Ruby_SplayTree tree = Ruby_SplayTree();
    for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
      insert_new_node(tree, rng);
    }
    return tree;
  }

  auto splay_run(auto tree, auto rng) {
    for (int64_t _i = 0; _i < MODIFICATIONS; _i++) {
      key = insert_new_node(tree, rng);
      greatest = tree.find_greatest_less_than(key);
      if (greatest) {
        tree.remove(greatest.key());
      } else {
        tree.remove(key);
      };
    }
    return INT64_C(0);
  }

  Ruby_PayloadNode(int64_t left, int64_t right) {
    iv_left = left;
    iv_right = right;
  }
};


static const int64_t TREE_SIZE = 8000LL;
static const int64_t MODIFICATIONS = 80LL;
static const int64_t PAYLOAD_DEPTH = 5LL;

static auto generate_payload(auto depth, auto tag) {
  if ((depth == INT64_C(0))) {
    /* UNSUPPORTED: HashLiteral */;
  } else {
    Ruby_PayloadNode(generate_payload((depth - INT64_C(1)), tag), generate_payload((depth - INT64_C(1)), tag));
  }
}

static auto insert_new_node(auto tree, auto rng) {
  return loop();
}

static auto splay_setup(auto rng) {
  Ruby_SplayTree tree = Ruby_SplayTree();
  for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
    insert_new_node(tree, rng);
  }
  return tree;
}

static auto splay_run(auto tree, auto rng) {
  for (int64_t _i = 0; _i < MODIFICATIONS; _i++) {
    key = insert_new_node(tree, rng);
    greatest = tree.find_greatest_less_than(key);
    if (greatest) {
      tree.remove(greatest.key());
    } else {
      tree.remove(key);
    };
  }
  return INT64_C(0);
}


int main() {
  Ruby_Random rng = Ruby_Random(INT64_C(42));
  auto tree = splay_setup(rng);
  for (int64_t _i = 0; _i < INT64_C(200); _i++) {
    for (int64_t _i = 0; _i < INT64_C(50); _i++) {
      splay_run(tree, rng);
    };
  }
  auto m = tree.find_max();
  ruby_puts(m.key());
  return 0;
}
