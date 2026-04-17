#include "../runtime/frozone.hpp"

static const int64_t TREE_SIZE = 8000LL;
static const int64_t MODIFICATIONS = 80LL;
static const int64_t PAYLOAD_DEPTH = 5LL;

struct Ruby_Node {
  struct Impl {
    double iv_key = 0.0;
    std::shared_ptr<Impl> iv_left;
    std::shared_ptr<Impl> iv_right;
  };
  std::shared_ptr<Impl> p;

  Ruby_Node(std::shared_ptr<Impl> p_) : p(p_) {}
  operator std::shared_ptr<Impl>() const { return p; }
  Ruby_Node() = default;
  Ruby_Node(const RubyNil&) {}
  Ruby_Node(auto key, auto value) : p(std::make_shared<Impl>()) {
    p->iv_key = key;
    value;
    p->iv_left = RUBY_NIL;
    p->iv_right = RUBY_NIL;
  }

  auto key() {
    return p->iv_key;
  }

  auto set_key(auto __anon_req__) {
    p->iv_key = __anon_req__;
    return p->iv_key;
  }

  auto left() {
    return Ruby_Node(p->iv_left);
  }

  auto set_left(auto __anon_req__) {
    p->iv_left = __anon_req__;
    return Ruby_Node(p->iv_left);
  }

  auto right() {
    return Ruby_Node(p->iv_right);
  }

  auto set_right(auto __anon_req__) {
    p->iv_right = __anon_req__;
    return Ruby_Node(p->iv_right);
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_Node>() { return "Node"; }

struct Ruby_SplayTree {
  struct Impl {
    Ruby_Node iv_root;
  };
  std::shared_ptr<Impl> p;

  Ruby_SplayTree() : p(std::make_shared<Impl>()) {
    p->iv_root = RUBY_NIL;
  }
  Ruby_SplayTree(const RubyNil&) {}

  auto empty_q() {
    return ruby_nil_q(p->iv_root);
  }

  auto insert(auto key, auto value) {
    Ruby_Node node;
    if (empty_q()) {
      p->iv_root = Ruby_Node(key, value);
      return Ruby_Node();
    }
    splay_b(key);
    if ((p->iv_root.key() == key)) {
      return Ruby_Node();
    }
    (node = Ruby_Node(key, value));
    if ((key > p->iv_root.key())) {
      node.set_left(p->iv_root);
      node.set_right(p->iv_root.right());
      p->iv_root.set_right(RUBY_NIL);
    } else {
      node.set_right(p->iv_root);
      node.set_left(p->iv_root.left());
      p->iv_root.set_left(RUBY_NIL);
    }
    return p->iv_root = node;
  }

  auto remove(auto key) {
    Ruby_Node removed;
    Ruby_Node right;
    if (empty_q()) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
    splay_b(key);
    if ((p->iv_root.key() != key)) {
      { fprintf(stderr, "Error: %s\n", "error"); exit(1); };
    }
    (removed = p->iv_root);
    if (ruby_nil_q(p->iv_root.left())) {
      p->iv_root = p->iv_root.right();
    } else {
      (right = p->iv_root.right());
      p->iv_root = p->iv_root.left();
      splay_b(key);
      p->iv_root.set_right(right);
    }
    return removed;
  }

  auto find(auto key) {
    if (empty_q()) {
      return Ruby_Node(RUBY_NIL);
    }
    splay_b(key);
    if ((p->iv_root.key() == key)) {
      return p->iv_root;
    } else {
      return Ruby_Node(RUBY_NIL);
    }
  }

  auto find_max(Ruby_Node start_node = Ruby_Node(RUBY_NIL)) {
    Ruby_Node current;
    if (empty_q()) {
      return Ruby_Node(RUBY_NIL);
    }
    (current = ({ auto _l = (start_node); (_l) ? decltype((p->iv_root))(_l) : (p->iv_root); }));
    while (current.right()) {
      (current = current.right());
    }
    return current;
  }

  auto find_greatest_less_than(auto key) {
    if (empty_q()) {
      return Ruby_Node(RUBY_NIL);
    }
    splay_b(key);
    if ((p->iv_root.key() < key)) {
      return p->iv_root;
    } else {
      if (p->iv_root.left()) {
        return find_max(p->iv_root.left());
      }
      return Ruby_Node(RUBY_NIL);
    }
  }

  auto splay_b(auto key) {
    Ruby_Node dummy;
    Ruby_Node left;
    Ruby_Node right;
    Ruby_Node current;
    Ruby_Node tmp;
    if (empty_q()) {
      return Ruby_Node();
    }
    (dummy = Ruby_Node(RUBY_NIL, RUBY_NIL));
    (left = dummy);
    (right = dummy);
    (current = p->iv_root);
    while (true) {
      if ((key < current.key())) {
        if (!(current.left())) {
        break;
      };
        if ((key < current.left().key())) {
        (tmp = current.left());
        current.set_left(tmp.right());
        tmp.set_right(current);
        (current = tmp);
        if (!(current.left())) {
        break;
      };
      };
        right.set_left(current);
        (right = current);
        (current = current.left());
      } else {
        if ((key > current.key())) {
        if (!(current.right())) {
        break;
      };
        if ((key > current.right().key())) {
        (tmp = current.right());
        current.set_right(tmp.left());
        tmp.set_left(current);
        (current = tmp);
        if (!(current.right())) {
        break;
      };
      };
        left.set_right(current);
        (left = current);
        (current = current.right());
      } else {
        break;
      };
      };
    }
    left.set_right(current.left());
    right.set_left(current.right());
    current.set_left(dummy.right());
    current.set_right(dummy.left());
    return p->iv_root = current;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_SplayTree>() { return "SplayTree"; }

struct Ruby_PayloadNode {
  struct Impl {
  };
  std::shared_ptr<Impl> p;

  Ruby_PayloadNode() = default;
  Ruby_PayloadNode(const RubyNil&) {}
  Ruby_PayloadNode(auto left, auto right) : p(std::make_shared<Impl>()) {
    left;
    right;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_PayloadNode>() { return "PayloadNode"; }




static std::any generate_payload(auto depth, auto tag) {
  if ((depth == INT64_C(0))) {
    return ({ RubyHash<RubySymbol, std::any> _h; _h.store(ruby_sym("array"), std::any(({ auto _e0 = INT64_C(0); auto _a = RubyArray<decltype(_e0)>(10); _a[0] = _e0; _a[1] = INT64_C(1); _a[2] = INT64_C(2); _a[3] = INT64_C(3); _a[4] = INT64_C(4); _a[5] = INT64_C(5); _a[6] = INT64_C(6); _a[7] = INT64_C(7); _a[8] = INT64_C(8); _a[9] = INT64_C(9); _a; }))); _h.store(ruby_sym("string"), std::any((RubyString("String for key ", 15) + ruby_to_s(tag) + RubyString(" in leaf node", 13)))); _h; });
  } else {
    return Ruby_PayloadNode(generate_payload((depth - INT64_C(1)), tag), generate_payload((depth - INT64_C(1)), tag));
  }
}

static auto insert_new_node(auto tree, auto rng) {
  std::decay_t<decltype(rng.rand())> key{};
  while (true) {
    (key = rng.rand());
    if (tree.find(key)) {
      continue;
    };
    tree.insert(key, generate_payload(PAYLOAD_DEPTH, ruby_to_s(key)));
    return key;
  }
  __builtin_unreachable();
}

static auto splay_setup(auto rng) {
  Ruby_SplayTree tree;
  (tree = Ruby_SplayTree());
  for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
    insert_new_node(tree, rng);
  }
  return tree;
}

static auto splay_run(auto tree, auto rng) {
  std::decay_t<decltype(insert_new_node(tree, rng))> key{};
  std::decay_t<decltype(tree.find_greatest_less_than(key))> greatest{};
  for (int64_t _i = 0; _i < MODIFICATIONS; _i++) {
    (key = insert_new_node(tree, rng));
    (greatest = tree.find_greatest_less_than(key));
    (greatest ? (tree.remove(greatest.key())) : (tree.remove(key)));
  }
  return RUBY_NIL;
}


int main() {
  Ruby_Random rng;
  Ruby_SplayTree tree;
  Ruby_Node m;
  (rng = Ruby_Random(INT64_C(42)));
  (tree = splay_setup(rng));
  for (int64_t _i = 0; _i < INT64_C(200); _i++) {
    for (int64_t _i = 0; _i < INT64_C(50); _i++) {
      splay_run(tree, rng);
    };
  }
  (m = tree.find_max());
  ruby_puts(m.key());
  return 0;
}
