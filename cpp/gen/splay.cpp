#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>

// --- Frozone C++ runtime (minimal) ---

#include <memory>
#include <type_traits>
#include <charconv>
#include <cinttypes>

// Mutable byte-oriented string. Encoding is tracked nominally
// but all methods operate on bytes (matches Ruby binary semantics).
#include <vector>
#include <cstring>
class RubyString {
public:
  std::vector<uint8_t> bytes;
  RubyString() = default;
  RubyString(const char* s) { if (s) { size_t n = strlen(s); bytes.assign(s, s + n); } }
  RubyString(const char* s, size_t n) { bytes.assign(s, s + n); }
  int64_t len() const { return (int64_t)bytes.size(); }
  int64_t bytesize() const { return (int64_t)bytes.size(); }
  int64_t size() const { return (int64_t)bytes.size(); }
  int64_t length() const { return (int64_t)bytes.size(); }
  int64_t get_byte(int64_t i) const { return (i >= 0 && i < (int64_t)bytes.size()) ? (int64_t)bytes[i] : 0; }
  void set_byte(int64_t i, int64_t v) { if (i >= 0 && i < (int64_t)bytes.size()) bytes[i] = (uint8_t)(v & 0xff); }
  RubyString dup_() const { return *this; }
  RubyString& operator<<(const RubyString& o) {
    bytes.insert(bytes.end(), o.bytes.begin(), o.bytes.end()); return *this;
  }
  RubyString& operator<<(const char* s) {
    if (s) { size_t n = strlen(s); bytes.insert(bytes.end(), s, s + n); } return *this;
  }
  bool operator==(const RubyString& o) const { return bytes == o.bytes; }
  bool operator!=(const RubyString& o) const { return bytes != o.bytes; }
};
using Ruby_String = RubyString;

// Generic native array — TI-specialised per element type.
// shared_ptr<vector<T>> backing: copy is cheap (alias), growable via <<.
template<typename T> class RubyArray {
public:
  std::shared_ptr<std::vector<T>> data;
  RubyArray() : data(std::make_shared<std::vector<T>>()) {}
  RubyArray(int64_t size) : data(std::make_shared<std::vector<T>>(size)) {}
  RubyArray(int64_t size, T fill) : data(std::make_shared<std::vector<T>>(size, fill)) {}
  int64_t len() const { return data ? (int64_t)data->size() : 0; }
  T& operator[](int64_t i) { return (*data)[i]; }
  const T& operator[](int64_t i) const { return (*data)[i]; }
  RubyArray& operator<<(const T& v) { data->push_back(v); return *this; }
};

using RubyArray_I64 = RubyArray<int64_t>;
using RubyArray_F64 = RubyArray<double>;
// Helper: deduce array element type from fill value
template<typename T> RubyArray<T> make_ra(int64_t n, T fill) { return RubyArray<T>(n, fill); }

struct RubyNil;

// RubyTree — value-semantic shared-ownership binary tree node.
// Node holds two child shared_ptrs; default-constructed tree is nil.
struct RubyTreeNode;
class RubyTree {
public:
  std::shared_ptr<RubyTreeNode> node;
  RubyTree() = default;
  RubyTree(RubyTree l, RubyTree r);
  RubyTree(const RubyNil&) {}
  bool nil_q() const { return !node; }
  RubyTree operator[](int64_t i) const;
  int64_t len() const { return node ? 2 : 0; }
};
struct RubyTreeNode { std::shared_ptr<RubyTreeNode> left, right; };
inline RubyTree::RubyTree(RubyTree l, RubyTree r) {
  node = std::make_shared<RubyTreeNode>();
  node->left = l.node;
  node->right = r.node;
}
inline RubyTree RubyTree::operator[](int64_t i) const {
  RubyTree t; t.node = (i == 0 ? node->left : node->right); return t;
}

struct RubyNil {
  operator int64_t() const { return 0; }
  operator double() const { return 0.0; }
  operator bool() const { return false; }
  operator RubyString() const { return RubyString(); }
  template<typename T> operator std::shared_ptr<T>() const { return nullptr; }
  template<typename T> operator T() const { return T(); }
};
static const RubyNil RUBY_NIL;

// Uniform nil check — dispatches on type.
static inline bool ruby_nil_q(const RubyTree& t) { return t.nil_q(); }
template<typename T> static inline bool ruby_nil_q(const std::shared_ptr<T>& p) { return !p; }
template<typename T> static inline bool ruby_nil_q(const T&) { return false; }

// Object.new — empty class with universal "GenericObject" class name.
struct Ruby_Object {};

// .class method — template dispatches on runtime type.
template<typename T> static inline const char* ruby_class_name() { return "Object"; }
template<> inline const char* ruby_class_name<int64_t>() { return "Integer"; }
template<> inline const char* ruby_class_name<double>() { return "Float"; }
template<> inline const char* ruby_class_name<bool>() { return "TrueClass"; }
template<> inline const char* ruby_class_name<RubyString>() { return "String"; }
template<> inline const char* ruby_class_name<Ruby_Object>() { return "GenericObject"; }
template<typename T> static inline const char* ruby_class(const T&) { return ruby_class_name<T>(); }

// to_s — converts primitives to RubyString. Class-specific overrides on user classes.
template<typename T> static inline RubyString ruby_to_s(T v) {
  if constexpr (std::is_same_v<T, RubyString>) return v;
  else if constexpr (std::is_floating_point_v<T>) {
    char buf[64]; auto r = std::to_chars(buf, buf + sizeof(buf) - 4, (double)v);
    *r.ptr = 0;
    bool has_dot = false; for (char* p = buf; p < r.ptr; ++p) if (*p == '.' || *p == 'e' || *p == 'n' || *p == 'i') { has_dot = true; break; }
    if (!has_dot) { *r.ptr++ = '.'; *r.ptr++ = '0'; *r.ptr = 0; }
    return RubyString(buf);
  } else if constexpr (std::is_integral_v<T>) {
    char buf[32]; snprintf(buf, sizeof(buf), "%lld", (long long)v); return RubyString(buf);
  } else return RubyString("#<Object>");
}

// Ruby_Random — MT19937-based (matches Ruby's Random#rand semantics).
class Ruby_Random {
public:
  uint32_t mt[624];
  int index = 624;
  Ruby_Random() = default;
  Ruby_Random(int64_t seed) { reseed((uint32_t)seed); }
  void reseed(uint32_t seed) {
    mt[0] = seed;
    for (int i = 1; i < 624; i++) mt[i] = 1812433253U * (mt[i-1] ^ (mt[i-1] >> 30)) + (uint32_t)i;
    index = 624;
  }
  uint32_t next_u32() {
    if (index >= 624) { generate(); index = 0; }
    uint32_t y = mt[index++];
    y ^= (y >> 11); y ^= (y << 7) & 0x9D2C5680U;
    y ^= (y << 15) & 0xEFC60000U; y ^= (y >> 18);
    return y;
  }
  void generate() {
    for (int i = 0; i < 624; i++) {
      uint32_t y = (mt[i] & 0x80000000U) | (mt[(i+1) % 624] & 0x7fffffffU);
      mt[i] = mt[(i+397) % 624] ^ (y >> 1);
      if (y & 1) mt[i] ^= 0x9908B0DFU;
    }
  }
  double rand() {
    uint32_t a = next_u32() >> 5, b = next_u32() >> 6;
    return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);
  }
  int64_t rand(int64_t n) { return (int64_t)(rand() * n); }
  bool nil_q() const { return false; }
};
template<> inline const char* ruby_class_name<Ruby_Random>() { return "Random"; }

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

static const int64_t TREE_SIZE = 8000LL;
static const int64_t MODIFICATIONS = 80LL;
static const int64_t PAYLOAD_DEPTH = 5LL;

struct Ruby_Node {
  struct Impl {
    int64_t iv_key = 0;
    int64_t iv_value = 0;
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
      p->iv_root = Ruby_Node(key, value); return Ruby_Node();
    }
    splay_b(key);
    if ((p->iv_root.key() == key)) {
      return Ruby_Node();
    }
    node = Ruby_Node(key, value);
    if ((key > p->iv_root.key())) {
      node.set_left(p->iv_root); node.set_right(p->iv_root.right()); p->iv_root.set_right(RUBY_NIL);
    } else {
      node.set_right(p->iv_root); node.set_left(p->iv_root.left()); p->iv_root.set_left(RUBY_NIL);
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
    removed = p->iv_root;
    if (ruby_nil_q(p->iv_root.left())) {
      p->iv_root = p->iv_root.right();
    } else {
      right = p->iv_root.right(); p->iv_root = p->iv_root.left(); splay_b(key); p->iv_root.set_right(right);
    }
    return removed;
  }

  auto find(auto key) {
    if (empty_q()) {
      return RUBY_NIL;
    }
    splay_b(key);
    if ((p->iv_root.key() == key)) {
      p->iv_root;
    } else {
      RUBY_NIL;
    }
  }

  auto find_max(auto start_node = RUBY_NIL) {
    Ruby_Node current;
    if (empty_q()) {
      return Ruby_Node(RUBY_NIL);
    }
    current = ({ auto _l = (start_node); auto _r = (p->iv_root); (_l) ? decltype(_r)(_l) : _r; });
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
    if ((p->iv_root.key() < key)) {
      p->iv_root;
    } else {
      if (p->iv_root.left()) {
        find_max(p->iv_root.left());
      };
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
    dummy = Ruby_Node(RUBY_NIL, RUBY_NIL);
    left = dummy;
    right = dummy;
    current = p->iv_root;
    while (true) {
      if ((key < current.key())) {
        if (!(current.left())) {
          break;
        }; if ((key < current.left().key())) {
          tmp = current.left(); current.set_left(tmp.right()); tmp.set_right(current); current = tmp; if (!(current.left())) {
            break;
          };
        }; right.set_left(current); right = current; current = current.left();
      } else {
        if ((key > current.key())) {
          if (!(current.right())) {
            break;
          }; if ((key > current.right().key())) {
            tmp = current.right(); current.set_right(tmp.left()); tmp.set_left(current); current = tmp; if (!(current.right())) {
              break;
            };
          }; left.set_right(current); left = current; current = current.right();
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
    Ruby_Node iv_left;
    Ruby_Node iv_right;
  };
  std::shared_ptr<Impl> p;

  Ruby_PayloadNode() = default;
  Ruby_PayloadNode(const RubyNil&) {}
  Ruby_PayloadNode(auto left, auto right) : p(std::make_shared<Impl>()) {
    p->iv_left = left;
    p->iv_right = right;
  }

  auto left() {
    return p->iv_left;
  }

  auto set_left(auto __anon_req__) {
    p->iv_left = __anon_req__;
    return p->iv_left;
  }

  auto right() {
    return p->iv_right;
  }

  auto set_right(auto __anon_req__) {
    p->iv_right = __anon_req__;
    return p->iv_right;
  }

  bool nil_q() const { return !p; }
  explicit operator bool() const { return (bool)p; }
};
template<> inline const char* ruby_class_name<Ruby_PayloadNode>() { return "PayloadNode"; }



static auto generate_payload(auto depth, auto tag) {
  if ((depth == INT64_C(0))) {
    /* UNSUPPORTED: HashLiteral */;
  } else {
    Ruby_PayloadNode(generate_payload((depth - INT64_C(1)), tag), generate_payload((depth - INT64_C(1)), tag));
  }
}

static auto insert_new_node(auto tree, auto rng) {
  std::decay_t<decltype(rng.rand())> key{};
  while (true) {
    key = rng.rand();
    if (tree.find(key)) {
      continue;
    };
    tree.insert(key, generate_payload(PAYLOAD_DEPTH, ruby_to_s(key)));
    return key;
  }
  return INT64_C(0);
}

static auto splay_setup(auto rng) {
  Ruby_SplayTree tree;
  tree = Ruby_SplayTree();
  for (int64_t _i = 0; _i < TREE_SIZE; _i++) {
    insert_new_node(tree, rng);
  }
  return tree;
}

static auto splay_run(auto tree, auto rng) {
  std::decay_t<decltype(insert_new_node(tree, rng))> key{};
  for (int64_t _i = 0; _i < MODIFICATIONS; _i++) {
    key = insert_new_node(tree, rng);
    auto greatest = tree.find_greatest_less_than(key);
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
