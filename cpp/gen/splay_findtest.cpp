#include "../runtime/frozone.hpp"
#include "../runtime/frozone.hpp"

static const int64_t TREE_SIZE = 8000LL;
static const int64_t MODIFICATIONS = 80LL;
static const int64_t PAYLOAD_DEPTH = 5LL;

struct Ruby_Node {
  struct Impl {
    double iv_key = 0.0;
    std::any iv_value;
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
    p->iv_value = value;
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

  auto value() {
    return p->iv_value;
  }

  auto set_value(auto __anon_req__) {
    p->iv_value = __anon_req__;
    return p->iv_value;
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
    return ((p->iv_root.key() == key) ? (p->iv_root) : (Ruby_Node(RUBY_NIL)));
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
      p->iv_root;
    } else {
      if (p->iv_root.left()) {
      find_max(p->iv_root.left());
    };
    }
    return Ruby_Node(RUBY_NIL);
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
int main() {
  Ruby_SplayTree tree;
  tree.insert(0.374540, std::any(INT64_C(0)));
  auto r1 = tree.find(0.950714);
  fprintf(stderr, "find(0.95): nil=%d bool=%d\n", r1.nil_q(), (bool)r1);
  auto r2 = tree.find(0.374540);
  fprintf(stderr, "find(0.37): nil=%d bool=%d\n", r2.nil_q(), (bool)r2);
}
