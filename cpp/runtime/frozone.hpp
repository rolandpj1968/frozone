// Frozone C++ runtime — shared between all AOT-compiled Ruby programs.
// Generated from lib/frozone/compiler/cpp_emitter.rb; hand-edit for now.
// Single-header library: #include this in every generated .cpp.

#ifndef FROZONE_RUNTIME_HPP
#define FROZONE_RUNTIME_HPP

#if defined(FROZONE_USE_BOEHM_GC) && defined(FROZONE_USE_DUSTMAN_GC)
#error "define at most one of FROZONE_USE_BOEHM_GC, FROZONE_USE_DUSTMAN_GC"
#endif

#ifdef FROZONE_USE_BOEHM_GC
#include <gc/gc.h>
#define FROZONE_GC_INIT() GC_INIT()
#define FROZONE_GC_SHUTDOWN()
#elif defined(FROZONE_USE_DUSTMAN_GC)
#include "dustman/dustman.hpp"
// Disable evacuation: gc_ptrs passed across function calls as plain params
// aren't Dustman-tracked, so an evacuation cycle would leave stale pointers.
// Non-moving mark-sweep is safe and good enough for now.
#define FROZONE_GC_INIT() dustman::set_evacuation_threshold_percent(0)
#define FROZONE_GC_SHUTDOWN() dustman::detach_thread()
#else
#define FROZONE_GC_INIT()
#define FROZONE_GC_SHUTDOWN()
#endif

#include <cstdio>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cmath>
#include <memory>
#include <type_traits>
#include <charconv>
#include <cinttypes>
#include <vector>
#include <list>
#include <unordered_map>
#include <variant>
#include <optional>
#include <any>

// ── Forward declarations ─────────────────────────────────────────────
// Built-ins inherit from RubyObject so heterogeneous unions (e.g. in
// attr_accessor :value holding both Hash and PayloadNode) meet at a
// common base — one pointer type that Dustman can trace uniformly,
// replacing the std::any escape hatch.
class RubyString;

// ── Ruby class hierarchy (declarations) ──────────────────────────────
class RubyBasicObject {
public:
#ifdef FROZONE_USE_BOEHM_GC
  void* operator new(size_t size) { return GC_MALLOC(size); }
  void operator delete(void*) {}
#endif
  virtual ~RubyBasicObject() = default;
  virtual const char* rb_class_name() const { return "BasicObject"; }
  virtual RubyString rb_to_s() const;  // defined after RubyString
  virtual bool rb_equal(const RubyBasicObject* other) const { return this == other; }
};

class RubyObject : public RubyBasicObject {
public:
  const char* rb_class_name() const override { return "Object"; }
  RubyString rb_to_s() const override;  // defined after RubyString
};

using Ruby_Object = RubyObject;

#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<RubyBasicObject> : dustman::FieldList<RubyBasicObject> {};
template<> struct dustman::Tracer<RubyObject> : dustman::FieldList<RubyObject> {};
#endif

class RubyString : public RubyObject {
public:
  // RubyString is used heavily as a value type — in std::any, in
  // RubyArray<RubyString>, in RubyHash<K, RubyString>, as locals. std::any
  // internally does `new RubyString(x)` / `delete ptr`, which would route
  // through RubyBasicObject's Boehm-aware `operator new` → GC_MALLOC, but
  // std::any's external storage lives in unordered_map nodes that Boehm
  // doesn't scan, causing premature reclaim. Override operator new/delete
  // here back to the global heap. `dustman::alloc<RubyString>` bypasses
  // operator new entirely, so Dustman management still works when requested.
  static void* operator new(size_t n) { return ::operator new(n); }
  static void* operator new(size_t, void* p) noexcept { return p; }
  static void operator delete(void* p) noexcept { ::operator delete(p); }

  // Ruby-semantic byte string with UTF-8 / BINARY encoding awareness.
  // .length counts UTF-8 codepoints when tagged UTF-8; raw bytes
  // when tagged BINARY. Encoding promotion on << matches MRI:
  // BINARY receiver + UTF-8 non-ASCII rhs flips receiver to UTF-8.
  enum Enc { UTF8 = 0, BINARY = 1 };
  std::vector<uint8_t> bytes;
  Enc enc = UTF8;
  mutable int64_t length_cache = -1;  // -1 = not yet computed

  RubyString() = default;
  RubyString(bool) {}
  RubyString(int64_t) {}
  RubyString(const char* s) { if (s) { size_t n = strlen(s); bytes.assign(s, s + n); } }
  RubyString(const char* s, size_t n) { bytes.assign(s, s + n); }
  RubyString(const char* s, size_t n, Enc e) : enc(e) { bytes.assign(s, s + n); }

  int64_t bytesize() const { return (int64_t)bytes.size(); }
  // .length — O(n) first call (UTF-8 codepoint scan), O(1) cached;
  // BINARY strings: bytesize.
  int64_t length() const {
    if (enc == BINARY) return (int64_t)bytes.size();
    if (length_cache < 0) {
      int64_t n = 0;
      for (auto b : bytes) if ((b & 0xC0) != 0x80) n++;
      length_cache = n;
    }
    return length_cache;
  }
  int64_t size() const { return length(); }
  int64_t len() const { return length(); }  // legacy; emitter targets this
  bool has_non_ascii() const {
    for (auto b : bytes) if (b >= 0x80) return true;
    return false;
  }

  int64_t get_byte(int64_t i) const { return (i >= 0 && i < (int64_t)bytes.size()) ? (int64_t)bytes[i] : 0; }
  void set_byte(int64_t i, int64_t v) { if (i >= 0 && i < (int64_t)bytes.size()) { bytes[i] = (uint8_t)(v & 0xff); length_cache = -1; } }
  RubyString dup_() const { return *this; }
  int64_t ord() const { return bytes.empty() ? 0 : (int64_t)bytes[0]; }
  RubyString operator[](int64_t i) const {
    if (i < 0 || i >= (int64_t)bytes.size()) return RubyString();
    return RubyString((const char*)&bytes[i], 1);
  }
  // `.b` — return a copy re-tagged as BINARY.
  RubyString b() const { RubyString c(*this); c.enc = BINARY; c.length_cache = -1; return c; }

  RubyString& operator<<(const RubyString& o) {
    // MRI encoding promotion: BINARY + UTF-8 non-ASCII → UTF-8.
    if (enc == BINARY && o.enc == UTF8 && o.has_non_ascii()) enc = UTF8;
    bytes.insert(bytes.end(), o.bytes.begin(), o.bytes.end());
    length_cache = -1;
    return *this;
  }
  RubyString& operator<<(const char* s) {
    if (s) { size_t n = strlen(s); bytes.insert(bytes.end(), s, s + n); length_cache = -1; }
    return *this;
  }
  RubyString operator+(const RubyString& o) const { RubyString r(*this); r << o; return r; }
  RubyString operator*(int64_t n) const {
    RubyString r; r.enc = enc;
    for (int64_t i = 0; i < n; i++) r << *this;
    return r;
  }
  RubyString slice(int64_t from, int64_t len) const {
    if (from < 0 || from >= (int64_t)bytes.size() || len <= 0) return RubyString();
    int64_t end = std::min(from + len, (int64_t)bytes.size());
    return RubyString((const char*)&bytes[from], end - from, enc);
  }

  bool operator==(const RubyString& o) const { return bytes == o.bytes; }
  bool operator!=(const RubyString& o) const { return bytes != o.bytes; }
  bool operator<(const RubyString& o) const { return bytes < o.bytes; }
  bool operator<=(const RubyString& o) const { return bytes <= o.bytes; }
  bool operator>(const RubyString& o) const { return bytes > o.bytes; }
  bool operator>=(const RubyString& o) const { return bytes >= o.bytes; }

  const char* rb_class_name() const override { return "String"; }
  RubyString rb_to_s() const override { return *this; }
};
using Ruby_String = RubyString;

inline RubyString RubyBasicObject::rb_to_s() const { return RubyString("#<BasicObject>"); }
inline RubyString RubyObject::rb_to_s() const { return RubyString("#<Object>"); }

#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<RubyString> : dustman::FieldList<RubyString> {};
#endif

// Boxed primitive wrappers. Required when a primitive (int64_t / double /
// bool) participates in a union alongside a gc_ref-holding type — storing the
// primitive in `std::any` alongside an object pointer would be Dustman-unsafe
// (precise GC can't see into std::any's type-erased storage). Boxing lifts
// primitives into the gc_ref<RubyObject> union model, keeping the whole union
// precisely traceable.
//
// For pure-primitive unions (no gc_refs involved), `std::any` with SBO is
// still the cheaper choice — the emitter picks based on participant set.
class Ruby_Integer : public RubyObject {
public:
  static void* operator new(size_t n) { return ::operator new(n); }
  static void* operator new(size_t, void* p) noexcept { return p; }
  static void operator delete(void* p) noexcept { ::operator delete(p); }
  int64_t value;
  Ruby_Integer() : value(0) {}
  Ruby_Integer(int64_t v) : value(v) {}
  const char* rb_class_name() const override { return "Integer"; }
};

class Ruby_Float : public RubyObject {
public:
  static void* operator new(size_t n) { return ::operator new(n); }
  static void* operator new(size_t, void* p) noexcept { return p; }
  static void operator delete(void* p) noexcept { ::operator delete(p); }
  double value;
  Ruby_Float() : value(0.0) {}
  Ruby_Float(double v) : value(v) {}
  const char* rb_class_name() const override { return "Float"; }
};

class Ruby_Boolean : public RubyObject {
public:
  static void* operator new(size_t n) { return ::operator new(n); }
  static void* operator new(size_t, void* p) noexcept { return p; }
  static void operator delete(void* p) noexcept { ::operator delete(p); }
  bool value;
  Ruby_Boolean() : value(false) {}
  Ruby_Boolean(bool v) : value(v) {}
  const char* rb_class_name() const override { return value ? "TrueClass" : "FalseClass"; }
};

// Forward-decl for Ruby_Symbol — full definition below once RubySymbol is
// declared. Same lazy-box pattern as the primitives above: bare RubySymbol
// stays 8 bytes (hash-key efficient), Ruby_Symbol wraps it for union entry.
class RubySymbol;
class Ruby_Symbol;

#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Integer> : dustman::FieldList<Ruby_Integer> {};
template<> struct dustman::Tracer<Ruby_Float>   : dustman::FieldList<Ruby_Float>   {};
template<> struct dustman::Tracer<Ruby_Boolean> : dustman::FieldList<Ruby_Boolean> {};
// Ruby_Symbol tracer further down after the class body.
#endif

// ---------------------------------------------------------------------
// RubySymbol — interned string. Ruby symbols with the same text are the
// same object; comparison is O(1). We intern via a process-wide map of
// string → stable char*. RubySymbol stores the interned pointer;
// equality is pointer-equality.
// ---------------------------------------------------------------------
class RubySymbol {
public:
  const char* name = nullptr;  // interned, null-terminated

  RubySymbol() = default;
  explicit RubySymbol(const char* n) : name(n) {}  // pre-interned
  bool operator==(const RubySymbol& o) const { return name == o.name; }
  bool operator!=(const RubySymbol& o) const { return name != o.name; }
};

// Boxed symbol — for union entry only. Bare RubySymbol stays 8 bytes so
// unordered_map<RubySymbol, V> hash-node size is unchanged in the common
// case (hash keys). Ruby_Symbol is allocated via gc_new only when a
// symbol value crosses into a heterogeneous gc_ref<RubyObject> union.
class Ruby_Symbol : public RubyObject {
public:
  static void* operator new(size_t n) { return ::operator new(n); }
  static void* operator new(size_t, void* p) noexcept { return p; }
  static void operator delete(void* p) noexcept { ::operator delete(p); }
  RubySymbol value;
  Ruby_Symbol() = default;
  Ruby_Symbol(RubySymbol v) : value(v) {}
  const char* rb_class_name() const override { return "Symbol"; }
};

#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Symbol> : dustman::FieldList<Ruby_Symbol> {};
#endif

// Interning table — static, leaks at shutdown (fine for AOT programs).
// Uses a map from std::string (because we hash the text) to the owned
// interned strdup'd char*. Subsequent sym() calls with the same text
// return the same pointer.
inline RubySymbol ruby_sym(const char* s) {
  static std::unordered_map<std::string, const char*> interned;
  auto it = interned.find(s);
  if (it != interned.end()) return RubySymbol(it->second);
  char* copy = strdup(s);
  interned.emplace(s, copy);
  return RubySymbol(copy);
}

// std::hash specialisation so RubySymbol works as a key.
namespace std {
  template<> struct hash<RubySymbol> {
    size_t operator()(const RubySymbol& s) const noexcept {
      // Hash the pointer (works because interning guarantees uniqueness).
      return std::hash<const void*>{}(s.name);
    }
  };
}

// ---------------------------------------------------------------------
// RubyHash<K, V> — insertion-ordered map. O(1) insert / lookup / delete.
// Under the hood: std::list for order + std::unordered_map storing the
// value alongside a stable iterator into the list.
// Copy semantics: deep. Copying rebuilds list iterators in the map.
// ---------------------------------------------------------------------
template<typename K, typename V>
class RubyHash : public RubyObject {
public:
  // Value-type usage (in std::any, in fields, as locals). Override operator
  // new/delete so `new RubyHash(x)` doesn't route through Boehm's GC_MALLOC —
  // see RubyString for rationale.
  static void* operator new(size_t n) { return ::operator new(n); }
  static void* operator new(size_t, void* p) noexcept { return p; }
  static void operator delete(void* p) noexcept { ::operator delete(p); }

  const char* rb_class_name() const override { return "Hash"; }

  using ListType = std::list<K>;
  using MapEntry = std::pair<V, typename ListType::iterator>;

  ListType order;
  std::unordered_map<K, MapEntry> data;

  RubyHash() = default;

  // Copy ctor: rebuild the list, rebuild the map pointing at the new list.
  RubyHash(const RubyHash& o) {
    for (const auto& k : o.order) {
      order.push_back(k);
      auto it = std::prev(order.end());
      auto src = o.data.find(k);
      data.emplace(k, MapEntry{src->second.first, it});
    }
  }
  RubyHash& operator=(const RubyHash& o) {
    if (this == &o) return *this;
    order.clear(); data.clear();
    for (const auto& k : o.order) {
      order.push_back(k);
      auto it = std::prev(order.end());
      auto src = o.data.find(k);
      data.emplace(k, MapEntry{src->second.first, it});
    }
    return *this;
  }
  RubyHash(RubyHash&&) = default;
  RubyHash& operator=(RubyHash&&) = default;

  int64_t len() const { return (int64_t)order.size(); }
  int64_t size() const { return len(); }
  int64_t length() const { return len(); }
  bool empty_q() const { return order.empty(); }

  // h[k] returns V&, inserting default-V if absent (Ruby `h[:missing]` is
  // nil; we return a default-constructed V which is nil-ish for variants).
  V& operator[](const K& k) {
    auto it = data.find(k);
    if (it != data.end()) return it->second.first;
    order.push_back(k);
    auto list_it = std::prev(order.end());
    auto [new_it, _] = data.emplace(k, MapEntry{V{}, list_it});
    return new_it->second.first;
  }

  // .store(k, v) — explicit insert / overwrite. Always updates value;
  // preserves insertion position on re-insert.
  V& store(const K& k, const V& v) {
    auto it = data.find(k);
    if (it != data.end()) {
      it->second.first = v;
      return it->second.first;
    }
    order.push_back(k);
    auto list_it = std::prev(order.end());
    auto [new_it, _] = data.emplace(k, MapEntry{v, list_it});
    return new_it->second.first;
  }

  bool include_q(const K& k) const { return data.count(k) > 0; }
  bool has_key_q(const K& k) const { return include_q(k); }

  void delete_(const K& k) {
    auto it = data.find(k);
    if (it == data.end()) return;
    order.erase(it->second.second);  // O(1) via stored iterator
    data.erase(it);
  }

  // Iteration walks the order list — insertion-ordered.
  auto begin() const { return order.begin(); }
  auto end() const { return order.end(); }
};

#ifdef FROZONE_USE_DUSTMAN_GC
// Walking Tracer for RubyHash: iterate storage and visit any K / V slots
// that are gc_ptr-based (i.e. references to Dustman-managed objects).
// Storage lives in malloc-backed std::list + std::unordered_map nodes —
// Dustman doesn't scan those itself, so the Tracer is the only path by
// which the collector learns about gc_refs held inside the hash.
//
// Map keys are `const K` (unordered_map invariant) so a const_cast is
// needed to hand them to Visitor::visit, which takes a mutable reference
// so moving collectors can rewrite forwarded pointers. Currently we run
// non-moving so marks-only traverse, but we keep the signature honest.
template<typename K, typename V> struct dustman::Tracer<RubyHash<K, V>> {
  static void trace(RubyHash<K, V>& h, dustman::Visitor& v) {
    if constexpr (std::is_base_of_v<dustman::gc_ptr_base, K>) {
      for (auto& k : h.order) v.visit(k);
      for (auto& kv : h.data) v.visit(const_cast<K&>(kv.first));
    }
    if constexpr (std::is_base_of_v<dustman::gc_ptr_base, V>) {
      for (auto& kv : h.data) v.visit(kv.second.first);
    }
  }
};
#endif

// Forward declaration: ruby_to_s is used inside RubyArray::join.
template<typename T> static inline RubyString ruby_to_s(T v);

// Generic native array — TI-specialised per element type.
// shared_ptr<vector<T>> backing: copy is cheap (alias), growable via <<.
template<typename T> class RubyArray : public RubyObject {
public:
  // Value-type usage; keep `new`/`delete` on the regular heap so
  // std::any<RubyArray<...>> doesn't crash under Boehm. See RubyString.
  static void* operator new(size_t n) { return ::operator new(n); }
  static void* operator new(size_t, void* p) noexcept { return p; }
  static void operator delete(void* p) noexcept { ::operator delete(p); }

  const char* rb_class_name() const override { return "Array"; }

  std::shared_ptr<std::vector<T>> data;
  RubyArray() : data(std::make_shared<std::vector<T>>()) {}
  RubyArray(int64_t size) : data(std::make_shared<std::vector<T>>(size)) {}
  RubyArray(int64_t size, T fill) : data(std::make_shared<std::vector<T>>(size, fill)) {}
  int64_t len() const { return data ? (int64_t)data->size() : 0; }
  T& operator[](int64_t i) {
    if (i < 0) i += (int64_t)data->size();  // Ruby-style negative indexing
    return (*data)[i];
  }
  const T& operator[](int64_t i) const {
    if (i < 0) i += (int64_t)data->size();
    return (*data)[i];
  }
  T fetch(int64_t i) const { if (i < 0) i += (int64_t)data->size(); return (*data)[i]; }
  RubyArray& operator<<(const T& v) { data->push_back(v); return *this; }
  // .delete_at(i) — remove and return element at index (Ruby-style).
  T delete_at(int64_t i) {
    if (i < 0) i += (int64_t)data->size();
    if (i < 0 || i >= (int64_t)data->size()) return T{};
    T v = (*data)[i];
    data->erase(data->begin() + i);
    return v;
  }
  // .insert(i, v) — insert v at index i, shifting right.
  RubyArray& insert(int64_t i, const T& v) {
    if (i < 0) i += (int64_t)data->size() + 1;
    if (i < 0) i = 0;
    if (i > (int64_t)data->size()) i = (int64_t)data->size();
    data->insert(data->begin() + i, v);
    return *this;
  }
  // .slice_assign(lo, hi_incl, other) — replace elements [lo..hi_incl] with other's elements.
  void slice_assign(int64_t lo, int64_t hi_incl, const RubyArray& other) {
    if (lo < 0) lo += (int64_t)data->size();
    if (hi_incl < 0) hi_incl += (int64_t)data->size();
    if (lo < 0) lo = 0;
    if (hi_incl >= (int64_t)data->size()) hi_incl = (int64_t)data->size() - 1;
    data->erase(data->begin() + lo, data->begin() + hi_incl + 1);
    data->insert(data->begin() + lo, other.data->begin(), other.data->end());
  }
  // .dup — deep copy of the backing vector (breaks shared_ptr aliasing).
  RubyArray dup_() const {
    RubyArray out;
    *out.data = *data;
    return out;
  }
  // .join — concatenate elements (with optional separator) into a RubyString.
  RubyString join(const RubyString& sep = RubyString()) const {
    RubyString out;
    for (size_t i = 0; i < data->size(); i++) {
      if (i > 0) out << sep;
      out << ruby_to_s((*data)[i]);
    }
    return out;
  }
};

using RubyArray_I64 = RubyArray<int64_t>;
using Ruby_Array = RubyArray<int64_t>;
using RubyArray_F64 = RubyArray<double>;

#ifdef FROZONE_USE_DUSTMAN_GC
// Empty Tracer: elements live inside shared_ptr<vector<T>> on the regular
// heap. Revisit when containers become Dustman-allocated.
// Walking Tracer for RubyArray: iterate the vector and visit each element
// when T is a gc_ptr-based reference. Elements live in a malloc-backed
// std::vector owned via shared_ptr — Dustman's only visibility is through
// this trace.
template<typename T> struct dustman::Tracer<RubyArray<T>> {
  static void trace(RubyArray<T>& arr, dustman::Visitor& v) {
    if constexpr (std::is_base_of_v<dustman::gc_ptr_base, T>) {
      if (arr.data) {
        for (auto& e : *arr.data) v.visit(e);
      }
    }
  }
};
#endif
// Helper: deduce array element type from fill value
template<typename T> RubyArray<T> make_ra(int64_t n, T fill) { return RubyArray<T>(n, fill); }
// (lo..hi).to_a / (lo...hi).to_a — int64_t range enumeration.
static inline RubyArray<int64_t> ruby_range_to_a(int64_t lo, int64_t hi, bool exclusive) {
  int64_t end_inclusive = exclusive ? hi - 1 : hi;
  int64_t n = end_inclusive < lo ? 0 : (end_inclusive - lo + 1);
  RubyArray<int64_t> a(n);
  for (int64_t i = 0; i < n; i++) (*a.data)[i] = lo + i;
  return a;
}

struct RubyNil;

// RubyTree — value-semantic shared-ownership binary tree node.
// Node holds two child shared_ptrs; default-constructed tree is nil.
struct RubyTreeNode;
class RubyTree : public RubyObject {
public:
  // Value-type usage; keep `new`/`delete` on the regular heap. See RubyString.
  static void* operator new(size_t n) { return ::operator new(n); }
  static void* operator new(size_t, void* p) noexcept { return p; }
  static void operator delete(void* p) noexcept { ::operator delete(p); }

  const char* rb_class_name() const override { return "Tree"; }

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

#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<RubyTree> : dustman::FieldList<RubyTree> {};
#endif

struct RubyNil {
  operator int64_t() const { return 0; }
  operator double() const { return 0.0; }
  operator bool() const { return false; }
  operator RubyString() const { return RubyString(); }
  template<typename T> operator std::shared_ptr<T>() const { return nullptr; }
  // SFINAE out the nullptr_t case: assigning RubyNil to dustman::gc_ptr<T>
  // would otherwise be ambiguous (gc_ptr has both operator=(nullptr_t) and
  // operator=(const gc_ptr&), and RubyNil can convert to either via this
  // template). Excluding nullptr_t leaves only the gc_ptr<T>() path — one
  // conversion chain, unambiguous.
  template<typename T>
    requires (!std::is_same_v<T, std::nullptr_t>)
  operator T() const { return T(); }
};
static const RubyNil RUBY_NIL;

// Wrap a value into std::optional<T> for assignment to optional-typed locals.
// Direct `opt = RubyNil()` is wrong because operator=(U&&) prefers the
// RubyNil → int64_t conversion over RubyNil → optional<int64_t>. This helper
// dispatches on the source type so RubyNil → nullopt, optional<T> stays as-is,
// and other values get wrapped.
template<typename T, typename U>
inline std::optional<T> ruby_to_opt(U&& v) {
  if constexpr (std::is_same_v<std::decay_t<U>, RubyNil>) {
    return std::nullopt;
  } else if constexpr (std::is_same_v<std::decay_t<U>, std::optional<T>>) {
    return std::forward<U>(v);
  } else {
    return std::optional<T>(std::forward<U>(v));
  }
}

static inline bool ruby_nil_q(const RubyTree& t) { return t.nil_q(); }
template<typename T> static inline bool ruby_nil_q(T* p) { return p == nullptr; }
template<typename T> static inline bool ruby_nil_q(const std::shared_ptr<T>& p) { return !p; }
template<typename T> static inline bool ruby_nil_q(const std::optional<T>& o) { return !o.has_value(); }
#ifdef FROZONE_USE_DUSTMAN_GC
// Dustman refs: gc_ptr<T> is a smart pointer, Root<T> is a rooted slot.
// Both may be null; without these overloads the generic-T fallback below
// returns false on a null gc_ptr because gc_ptr has no .nil_q() member,
// silently breaking empty-check predicates.
template<typename T> static inline bool ruby_nil_q(const dustman::gc_ptr<T>& p) { return p.get() == nullptr; }
template<typename T> static inline bool ruby_nil_q(const dustman::Root<T>& r) { return r.get() == nullptr; }
#endif
template<typename T> static inline bool ruby_nil_q(const T& v) {
  if constexpr (requires { v.nil_q(); }) return v.nil_q();
  else return false;
}

// RubyBasicObject / RubyObject / RubyString declarations and Dustman
// Tracers moved to the top of the header (before RubyString) so RubyString
// can inherit from RubyObject. See there.


// ---------------------------------------------------------------------------
// GC abstractions: gc_ref<T>, gc_local<T>, gc_new<T>(...).
//
//   gc_ref<T>   — reference stored in an ivar, field, or passed as a param.
//                 Dustman: dustman::gc_ptr<T>. Boehm / none: plain T*.
//   gc_local<T> — stack-local reference that may live across allocations.
//                 Dustman: dustman::Root<T> (registered root, survives moves).
//                 Boehm / none: plain T*.
//   gc_new<T>(args...) — construct a GC-managed T, return the appropriate
//                 reference type. `new T(...)` under Boehm/none, dustman::alloc
//                 under Dustman.
//
// Emitter rule: use gc_local for locals holding user-class references;
// gc_ref for ivars/params/fields; gc_new for allocation. Arrays of references
// are RubyArray<gc_ref<T>> (not Dustman-traced yet — revisit for alloc-heavy
// benchmarks).
// ---------------------------------------------------------------------------
#ifdef FROZONE_USE_DUSTMAN_GC
template<typename T> using gc_ref   = dustman::gc_ptr<T>;
template<typename T> using gc_local = dustman::Root<T>;
template<typename T, typename... Args>
inline dustman::gc_ptr<T> gc_new(Args&&... args) {
  return dustman::alloc<T>(std::forward<Args>(args)...);
}
// Upcast a gc_ref<Derived> / gc_local<Derived> / Derived* to gc_ref<Base>.
// Dustman's gc_ptr<T> doesn't implicitly convert across T — templates are
// unrelated types even when the pointees share inheritance. as_ref does the
// static_cast-through-raw-pointer dance and wraps back into gc_ptr<Base>.
// Under Boehm/none gc_ref = T*, so this collapses to a plain static_cast.
template<typename Base, typename T>
inline dustman::gc_ptr<Base> as_ref(dustman::gc_ptr<T> p) {
  return dustman::gc_ptr<Base>(static_cast<Base*>(p.get()));
}
template<typename Base, typename T>
inline dustman::gc_ptr<Base> as_ref(const dustman::Root<T>& r) {
  return dustman::gc_ptr<Base>(static_cast<Base*>(r.get()));
}

// coerce_to_ref<Base>(x) — compile-time dispatch to produce a gc_ref<Base>
// from any compatible input. Used at union-entry sites where the incoming
// expression's type is only known at template-instantiation time (e.g. the
// `auto p` of an attr_writer body, where callers may pass a pointer-to-a-
// subclass OR a value-typed subclass instance). Works out:
//   - gc_ptr<Derived>   → as_ref<Base>(p)                     (pointer cast)
//   - Root<Derived>     → as_ref<Base>(r)                     (pointer cast)
//   - Base* / Derived*  → as_ref<Base>(p)                     (NA under Dustman)
//   - RubyObject-subclass value (RubyString, RubyHash<...>, etc.)
//                       → as_ref<Base>(gc_new<decayed>(x))    (heap-box then cast)
template<typename Base, typename T>
inline dustman::gc_ptr<Base> coerce_to_ref(T&& x) {
  using U = std::decay_t<T>;
  if constexpr (std::is_same_v<U, RubyNil> || std::is_null_pointer_v<U>) {
    return dustman::gc_ptr<Base>(nullptr);
  } else if constexpr (std::is_base_of_v<dustman::gc_ptr_base, U>) {
    return as_ref<Base>(x);
  } else if constexpr (std::is_base_of_v<Base, U>) {
    return as_ref<Base>(gc_new<U>(std::forward<T>(x)));
  } else if constexpr (std::is_same_v<U, bool>) {
    return as_ref<Base>(gc_new<Ruby_Boolean>(x));
  } else if constexpr (std::is_integral_v<U>) {
    return as_ref<Base>(gc_new<Ruby_Integer>(static_cast<int64_t>(x)));
  } else if constexpr (std::is_floating_point_v<U>) {
    return as_ref<Base>(gc_new<Ruby_Float>(static_cast<double>(x)));
  } else if constexpr (std::is_same_v<U, RubySymbol>) {
    return as_ref<Base>(gc_new<Ruby_Symbol>(x));
  } else {
    static_assert(sizeof(T) == 0,
                  "coerce_to_ref: no conversion to Base for this type");
  }
}
#else
template<typename T> using gc_ref   = T*;
template<typename T> using gc_local = T*;
template<typename T, typename... Args>
inline T* gc_new(Args&&... args) {
  return new T(std::forward<Args>(args)...);
}
template<typename Base, typename T>
inline Base* as_ref(T* p) { return static_cast<Base*>(p); }
// Non-Dustman variant — same contract as the Dustman overload above.
template<typename Base, typename T>
inline Base* coerce_to_ref(T&& x) {
  using U = std::decay_t<T>;
  if constexpr (std::is_same_v<U, RubyNil> || std::is_null_pointer_v<U>) {
    return nullptr;
  } else if constexpr (std::is_pointer_v<U>) {
    return as_ref<Base>(x);
  } else if constexpr (std::is_base_of_v<Base, U>) {
    return as_ref<Base>(gc_new<U>(std::forward<T>(x)));
  } else if constexpr (std::is_same_v<U, bool>) {
    return as_ref<Base>(gc_new<Ruby_Boolean>(x));
  } else if constexpr (std::is_integral_v<U>) {
    return as_ref<Base>(gc_new<Ruby_Integer>(static_cast<int64_t>(x)));
  } else if constexpr (std::is_floating_point_v<U>) {
    return as_ref<Base>(gc_new<Ruby_Float>(static_cast<double>(x)));
  } else if constexpr (std::is_same_v<U, RubySymbol>) {
    return as_ref<Base>(gc_new<Ruby_Symbol>(x));
  } else {
    static_assert(sizeof(T) == 0,
                  "coerce_to_ref: no conversion to Base for this type");
  }
}
#endif

// .class method — template dispatches on runtime type.
template<typename T> static inline const char* ruby_class_name() { return "Object"; }
template<> inline const char* ruby_class_name<int64_t>() { return "Integer"; }
template<> inline const char* ruby_class_name<double>() { return "Float"; }
template<> inline const char* ruby_class_name<bool>() { return "TrueClass"; }
template<> inline const char* ruby_class_name<RubyString>() { return "String"; }
template<> inline const char* ruby_class_name<Ruby_Object>() { return "Object"; }
template<typename T> static inline const char* ruby_class(const T& v) {
  if constexpr (std::is_pointer_v<T>) {
    return v ? v->rb_class_name() : "NilClass";
  } else if constexpr (requires { v.get(); v.operator->(); }) {
    // Smart-pointer-like (gc_ptr<T>, Root<T>): delegate via ->.
    return v ? v->rb_class_name() : "NilClass";
  } else {
    return ruby_class_name<T>();
  }
}

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
// Shared-ptr wrapped so copies share state (Ruby reference semantics).
class Ruby_Random {
  struct Impl {
    uint32_t mt[624];
    int index = 624;
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
  };
  std::shared_ptr<Impl> p;
public:
  Ruby_Random() : p(std::make_shared<Impl>()) {}
  Ruby_Random(int64_t seed) : p(std::make_shared<Impl>()) { p->reseed((uint32_t)seed); }
  double rand() {
    uint32_t a = p->next_u32() >> 5, b = p->next_u32() >> 6;
    return (a * 67108864.0 + b) * (1.0 / 9007199254740992.0);
  }
  int64_t rand(int64_t n) { return (int64_t)(rand() * n); }
  bool nil_q() const { return false; }
};
template<> inline const char* ruby_class_name<Ruby_Random>() { return "Random"; }
#ifdef FROZONE_USE_DUSTMAN_GC
template<> struct dustman::Tracer<Ruby_Random> : dustman::FieldList<Ruby_Random> {};
#endif

// Ruby-flavored puts: chooses format based on type
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
  } else if constexpr (std::is_same_v<T, RubyString>) {
    fwrite(v.bytes.data(), 1, v.bytes.size(), stdout);
    fputc('\n', stdout);
  } else if constexpr (requires { v.len(); v[0]; }) {
    // RubyArray: Ruby's puts prints each element on its own line
    // (recursive flatten). Empty array → empty line.
    if (v.len() == 0) { printf("\n"); }
    else for (int64_t i = 0; i < v.len(); i++) ruby_puts(v[i]);
  } else {
    printf("#<Object>\n");
  }
}
static inline void ruby_puts(const char* s) { printf("%s\n", s); }

// Optional: print value if has_value, else empty line (Ruby's `puts nil`).
// Lets TI-inferred `std::optional<T>` locals print correctly.
template<typename T>
static inline void ruby_puts(const std::optional<T>& v) {
  if (v.has_value()) ruby_puts(*v);
  else printf("\n");
}

// Ruby exception hierarchy for try/catch rescue emission.
#include <stdexcept>
#include <string>

class RubyException : public std::exception {
  std::string msg;
public:
  RubyException(const char* m = "RuntimeError") : msg(m) {}
  RubyException(const std::string& m) : msg(m) {}
  const char* what() const noexcept override { return msg.c_str(); }
  RubyString message() const { return RubyString(msg.c_str()); }
};

class Ruby_RuntimeError : public RubyException {
public: using RubyException::RubyException;
  Ruby_RuntimeError() : RubyException("RuntimeError") {}
};
class Ruby_ZeroDivisionError : public RubyException {
public: Ruby_ZeroDivisionError() : RubyException("divided by 0") {}
};
class Ruby_TypeError : public RubyException {
public: using RubyException::RubyException;
};
class Ruby_ArgumentError : public RubyException {
public: using RubyException::RubyException;
};
class Ruby_NameError : public RubyException {
public: using RubyException::RubyException;
};
class Ruby_IndexError : public RubyException {
public: using RubyException::RubyException;
};
class Ruby_RangeError : public RubyException {
public: using RubyException::RubyException;
};
class Ruby_StopIteration : public RubyException {
public: using RubyException::RubyException;
};
class Ruby_StandardError : public RubyException {
public: using RubyException::RubyException;
};

// Safe integer division — throws ZeroDivisionError like Ruby.
static inline int64_t ruby_div(int64_t a, int64_t b) {
  if (b == 0) throw Ruby_ZeroDivisionError();
  return a / b;
}
static inline double ruby_div(double a, double b) { return a / b; }
static inline double ruby_div(int64_t a, double b) { return (double)a / b; }
static inline double ruby_div(double a, int64_t b) { return a / (double)b; }
static inline int64_t ruby_mod(int64_t a, int64_t b) {
  if (b == 0) throw Ruby_ZeroDivisionError();
  return a % b;
}
static inline double ruby_mod(double a, double b) { return fmod(a, b); }
static inline double ruby_mod(int64_t a, double b) { return fmod((double)a, b); }
static inline double ruby_mod(double a, int64_t b) { return fmod(a, (double)b); }

#endif  // FROZONE_RUNTIME_HPP
