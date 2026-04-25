#include "../runtime/frozone.hpp"

static const int64_t TREE_SIZE = 8000LL;
static const int64_t MODIFICATIONS = 80LL;
static const int64_t PAYLOAD_DEPTH = 5LL;

struct Ruby_Node : public RubyObject {
  inline static const int64_t TREE_SIZE = 8000LL;
  inline static const int64_t MODIFICATIONS = 80LL;
  inline static const int64_t PAYLOAD_DEPTH = 5LL;
  double iv_key = 0.0;
  gc_ref<RubyObject> iv_value = nullptr;
  gc_ref<Ruby_Node> iv_left = nullptr;
  gc_ref<Ruby_Node> iv_right = nullptr;

  Ruby_Node() = default;
  Ruby_Node(auto key, auto value) {
    iv_key = key;
    iv_value = coerce_to_ref<RubyObject>(value);
    iv_left = nullptr;
    iv_right = nullptr;
  }
  const char* rb_class_name() const override { return "Node"; }

  auto key() {
    return iv_key;
  }

  auto set_key(auto __anon_req__) {
    iv_key = __anon_req__;
    return iv_key;
  }

  gc_ref<RubyObject> value() {
    return iv_value;
  }

  gc_ref<RubyObject> set_value(gc_ref<RubyObject> __anon_req__) {
    iv_value = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_value;
  }

  gc_ref<Ruby_Node> left() {
    return iv_left;
  }

  gc_ref<Ruby_Node> set_left(gc_ref<Ruby_Node> __anon_req__) {
    iv_left = __anon_req__;
    return iv_left;
  }

  gc_ref<Ruby_Node> right() {
    return iv_right;
  }

  gc_ref<Ruby_Node> set_right(gc_ref<Ruby_Node> __anon_req__) {
    iv_right = __anon_req__;
    return iv_right;
  }

};
template<> inline const char* ruby_class_name<Ruby_Node>() { return "Node"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Node> : dustman::FieldList<Ruby_Node, &Ruby_Node::iv_value, &Ruby_Node::iv_left, &Ruby_Node::iv_right> {};
#endif

struct Ruby_SplayTree : public RubyObject {
  inline static const int64_t TREE_SIZE = 8000LL;
  inline static const int64_t MODIFICATIONS = 80LL;
  inline static const int64_t PAYLOAD_DEPTH = 5LL;
  gc_ref<Ruby_Node> iv_root = nullptr;

  Ruby_SplayTree() {
    iv_root = nullptr;
  }
  const char* rb_class_name() const override { return "SplayTree"; }

  auto empty_q() {
    return ruby_nil_q(iv_root);
  }

  gc_ref<Ruby_Node> insert(auto key, gc_ref<RubyObject> value) {
    gc_local<Ruby_Node> node = nullptr;
    if (empty_q()) {
      iv_root = gc_new<Ruby_Node>(key, value);
      return gc_ref<Ruby_Node>(nullptr);
    }
    splay_b(key);
    if ((iv_root->key() == key)) {
      return gc_ref<Ruby_Node>(nullptr);
    }
    (node = gc_new<Ruby_Node>(key, value));
    if ((key > iv_root->key())) {
      node->set_left(iv_root);
      node->set_right(iv_root->right());
      iv_root->set_right(RUBY_NIL);
    } else {
      node->set_right(iv_root);
      node->set_left(iv_root->left());
      iv_root->set_left(RUBY_NIL);
    }
    return iv_root = node;
  }

  gc_ref<Ruby_Node> remove(auto key) {
    gc_local<Ruby_Node> removed = nullptr;
    gc_local<Ruby_Node> right = nullptr;
    if (empty_q()) {
      throw Ruby_RuntimeError();
    }
    splay_b(key);
    if ((iv_root->key() != key)) {
      throw Ruby_RuntimeError();
    }
    (removed = iv_root);
    if (ruby_nil_q(iv_root->left())) {
      iv_root = iv_root->right();
    } else {
      (right = iv_root->right());
      iv_root = iv_root->left();
      splay_b(key);
      iv_root->set_right(right);
    }
    return removed;
  }

  gc_ref<Ruby_Node> find(auto key) {
    if (empty_q()) {
      return gc_ref<Ruby_Node>(nullptr);
    }
    splay_b(key);
    if ((iv_root->key() == key)) {
      return iv_root;
    } else {
      return gc_ref<Ruby_Node>(nullptr);
    }
  }

  gc_ref<Ruby_Node> find_max(gc_ref<Ruby_Node> start_node = nullptr) {
    gc_local<Ruby_Node> current = nullptr;
    if (empty_q()) {
      return gc_ref<Ruby_Node>(nullptr);
    }
    (current = ({ auto _l = (start_node); (_l) ? decltype((iv_root))(_l) : (iv_root); }));
    while (current->right()) {
      (current = current->right());
    }
    return current;
  }

  gc_ref<Ruby_Node> find_greatest_less_than(auto key) {
    if (empty_q()) {
      return gc_ref<Ruby_Node>(nullptr);
    }
    splay_b(key);
    if ((iv_root->key() < key)) {
      return iv_root;
    } else {
      if (iv_root->left()) {
        return find_max(iv_root->left());
      }
      return gc_ref<Ruby_Node>(nullptr);
    }
  }

  gc_ref<Ruby_Node> splay_b(auto key) {
    gc_local<Ruby_Node> dummy = nullptr;
    gc_local<Ruby_Node> left = nullptr;
    gc_local<Ruby_Node> right = nullptr;
    gc_local<Ruby_Node> current = nullptr;
    gc_local<Ruby_Node> tmp = nullptr;
    if (empty_q()) {
      return gc_ref<Ruby_Node>(nullptr);
    }
    (dummy = gc_new<Ruby_Node>(RUBY_NIL, RUBY_NIL));
    (left = gc_ref<Ruby_Node>(dummy));
    (right = gc_ref<Ruby_Node>(dummy));
    (current = iv_root);
    while (true) {
      if ((key < current->key())) {
        if (!(current->left())) {
        break;
      };
        if ((key < current->left()->key())) {
        (tmp = current->left());
        current->set_left(tmp->right());
        tmp->set_right(current);
        (current = gc_ref<Ruby_Node>(tmp));
        if (!(current->left())) {
        break;
      };
      };
        right->set_left(current);
        (right = gc_ref<Ruby_Node>(current));
        (current = current->left());
      } else {
        if ((key > current->key())) {
        if (!(current->right())) {
        break;
      };
        if ((key > current->right()->key())) {
        (tmp = current->right());
        current->set_right(tmp->left());
        tmp->set_left(current);
        (current = gc_ref<Ruby_Node>(tmp));
        if (!(current->right())) {
        break;
      };
      };
        left->set_right(current);
        (left = gc_ref<Ruby_Node>(current));
        (current = current->right());
      } else {
        break;
      };
      };
    }
    left->set_right(current->left());
    right->set_left(current->right());
    current->set_left(dummy->right());
    current->set_right(dummy->left());
    return iv_root = current;
  }

};
template<> inline const char* ruby_class_name<Ruby_SplayTree>() { return "SplayTree"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_SplayTree> : dustman::FieldList<Ruby_SplayTree, &Ruby_SplayTree::iv_root> {};
#endif

struct Ruby_PayloadNode : public RubyObject {
  inline static const int64_t TREE_SIZE = 8000LL;
  inline static const int64_t MODIFICATIONS = 80LL;
  inline static const int64_t PAYLOAD_DEPTH = 5LL;
  gc_ref<RubyObject> iv_left = nullptr;
  gc_ref<RubyObject> iv_right = nullptr;

  Ruby_PayloadNode() = default;
  Ruby_PayloadNode(auto left, auto right) {
    iv_left = coerce_to_ref<RubyObject>(left);
    iv_right = coerce_to_ref<RubyObject>(right);
  }
  const char* rb_class_name() const override { return "PayloadNode"; }

  gc_ref<RubyObject> left() {
    return iv_left;
  }

  gc_ref<RubyObject> set_left(gc_ref<RubyObject> __anon_req__) {
    iv_left = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_left;
  }

  gc_ref<RubyObject> right() {
    return iv_right;
  }

  gc_ref<RubyObject> set_right(gc_ref<RubyObject> __anon_req__) {
    iv_right = coerce_to_ref<RubyObject>(__anon_req__);
    return iv_right;
  }

};
template<> inline const char* ruby_class_name<Ruby_PayloadNode>() { return "PayloadNode"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_PayloadNode> : dustman::FieldList<Ruby_PayloadNode, &Ruby_PayloadNode::iv_left, &Ruby_PayloadNode::iv_right> {};
#endif




static gc_ref<RubyObject> generate_payload(auto depth, auto tag) {
  if ((depth == INT64_C(0))) {
    return coerce_to_ref<RubyObject>(({ RubyHash<RubySymbol, gc_ref<RubyObject>> _h; _h.store(ruby_sym("array"), coerce_to_ref<RubyObject>(({ auto _e0 = INT64_C(0); auto _a = RubyArray<decltype(_e0)>(10); _a[0] = _e0; _a[1] = INT64_C(1); _a[2] = INT64_C(2); _a[3] = INT64_C(3); _a[4] = INT64_C(4); _a[5] = INT64_C(5); _a[6] = INT64_C(6); _a[7] = INT64_C(7); _a[8] = INT64_C(8); _a[9] = INT64_C(9); _a; }))); _h.store(ruby_sym("string"), coerce_to_ref<RubyObject>((RubyString("String for key ", 15) + ruby_to_s(tag) + RubyString(" in leaf node", 13)))); _h; }));
  } else {
    return coerce_to_ref<RubyObject>(gc_new<Ruby_PayloadNode>(generate_payload((depth - INT64_C(1)), tag), generate_payload((depth - INT64_C(1)), tag)));
  }
}

static auto insert_new_node(gc_ref<Ruby_SplayTree> tree, Ruby_Random* rng) {
  double key = 0.0;
  while (true) {
    (key = rng->rand());
    if (tree->find(key)) {
      continue;
    };
    tree->insert(key, generate_payload(PAYLOAD_DEPTH, ruby_to_s(key)));
    return key;
  }
  return double(RUBY_NIL);
}

static gc_ref<Ruby_SplayTree> splay_setup(Ruby_Random* rng) {
  gc_local<Ruby_SplayTree> tree = nullptr;
  (tree = gc_new<Ruby_SplayTree>());
  for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
    insert_new_node(tree, rng);
  }
  return tree;
}

static auto splay_run(gc_ref<Ruby_SplayTree> tree, Ruby_Random* rng) {
  double key = 0.0;
  gc_local<Ruby_Node> greatest = nullptr;
  for (int64_t _i = 0; _i < MODIFICATIONS; _i++) {
    (key = insert_new_node(tree, rng));
    (greatest = tree->find_greatest_less_than(key));
    (greatest ? (tree->remove(greatest->key())) : (tree->remove(key)));
  }
  return int64_t(RUBY_NIL);
}


int main() {
  FROZONE_GC_INIT();
  Ruby_Random* rng = nullptr;
  gc_local<Ruby_SplayTree> tree = nullptr;
  gc_local<Ruby_Node> m = nullptr;
  (rng = new Ruby_Random(INT64_C(42)));
  (tree = splay_setup(rng));
  for (int64_t _i = 0; _i < INT64_C(200); _i++) {
    for (int64_t _i = 0; _i < INT64_C(50); _i++) {
      splay_run(tree, rng);
    };
  }
  (m = tree->find_max());
  ruby_puts(m->key());
  FROZONE_GC_SHUTDOWN();
  return 0;
}
