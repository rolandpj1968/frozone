// Kernel-category intrinsic definitions. Declarations live in
// kernel_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "kernel_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Kernel --------------------------------------------------------

// `catch(tag) { |t| ... }` — wraps the block in try/catch matching on
// ThrownTag's identity tag (Symbols intern, so == is correct). Block
// receives the tag as its sole argument.
BasicObject* intrinsic_kernel_catch(BasicObject* /*self_*/, BasicObject* tag, BasicObject* block) {
  try {
    return static_cast<Proc*>(block)->m_call(univ, new Array({tag}));
  } catch (ThrownTag* _t) {
    if (_t->tag_ == tag) return _t->value_;
    throw;
  }
}

// `Intrinsics.dbg_write(str)` — bespoke raw-write to stderr for AOT-mode
// debugging. Bypasses ALL Ruby dispatch (no Symbol#to_s, no IO#puts, no
// $stdout introspection). Direct fputs(stderr) of the String's bytes +
// fflush so output appears immediately even on abort. Use when the
// regular puts chain is broken (e.g. during dispatch-table bring-up).
BasicObject* intrinsic_dbg_write(BasicObject* /*self_*/, BasicObject* s) {
  if (&typeid(*s) == &typeid(String)) {
    auto* str = static_cast<String*>(s);
    std::fwrite(str->bytes.data(), 1, str->bytes.size(), stderr);
    std::fputc('\n', stderr);
    std::fflush(stderr);
  } else if (s) {
    const char* cn = s->ruby_class_name();
    std::fprintf(stderr, "[dbg_write: non-String %s]\n", cn ? cn : "(null)");
    std::fflush(stderr);
  } else {
    std::fputs("[dbg_write: nullptr]\n", stderr);
    std::fflush(stderr);
  }
  return nil_instance();
}

// `Kernel#puts(*args)` via send/dynamic dispatch (direct `puts` already
// routes through ruby_puts at the call-site).
BasicObject* intrinsic_kernel_puts(BasicObject* /*self_*/, BasicObject* args_arr) {
  auto* _a = splat_to_array(args_arr);
  if (_a->data.empty()) {
    ruby_puts(static_cast<BasicObject*>(nullptr));
  } else {
    for (auto* _e : _a->data) ruby_puts(_e);
  }
  return nil_instance();
}

// `Kernel#print(*args)` — puts without trailing newline. Stub: route
// through ruby_puts (mismatch, but rarely visible).
BasicObject* intrinsic_kernel_print(BasicObject* /*self_*/, BasicObject* args_arr) {
  auto* _a = splat_to_array(args_arr);
  for (auto* _e : _a->data) ruby_puts(_e);
  return nil_instance();
}

// `Kernel#rand(n)` — global PRNG. Stub: route through a process-wide
// Random instance (deterministically seeded with 0). Real impl would
// seed with /dev/urandom.
BasicObject* intrinsic_kernel_rand(BasicObject* /*self_*/, BasicObject* n) {
  static Random* _g = nullptr;
  if (!_g) {
    _g = new Random();
    Integer _zero(0);
    _g->m_initialize(univ, new Array({static_cast<BasicObject*>(&_zero)}));
  }
  return _g->m_rand(univ, n == nil_instance() ? &EMPTY_ARGS : new Array({n}));
}

// `Kernel#Integer(val, base = nil, exception: true)` — coerce to
// Integer via existing helper.
BasicObject* intrinsic_kernel_integer(BasicObject* /*self_*/, BasicObject* val,
                                             BasicObject* /*base*/, BasicObject* /*exception*/) {
  return boxed_int(coerce_to_int(val));
}

// `Kernel#Float(val)` — coerce to Float. Fast path for Integer/Float;
// else dispatches to_f.
BasicObject* intrinsic_kernel_float(BasicObject* /*self_*/, BasicObject* val) {
  if (&typeid(*val) == &typeid(Integer)) return new Float(static_cast<double>(static_cast<Integer*>(val)->raw_));
  if (&typeid(*val) == &typeid(Float)) return val;
  return val->m_to_f(univ);
}

// ---- Fiber storage -------------------------------------------------

// `Fiber[:k]` — read from process-global storage Hash. Symbols intern
// so identity-keyed access is correct. Direct ->data avoids the
// universal op_aref/op_aset Array allocation.
BasicObject* intrinsic_fiber_storage_get(BasicObject* /*self_*/, BasicObject* key) {
  auto& _h = g_fiber_storage()->data;
  auto _it = _h.find(key);
  return (_it == _h.end()) ? nil_instance() : _it->second;
}

// `Fiber[:k] = v` — write to process-global storage Hash.
BasicObject* intrinsic_fiber_storage_set(BasicObject* /*self_*/, BasicObject* key, BasicObject* val) {
  g_fiber_storage()->put(key, val);
  return val;
}

BasicObject* intrinsic_fiber_storage_hash(BasicObject* /*self_*/) {
  return g_fiber_storage();
}

BasicObject* intrinsic_fiber_storage_hash_set(BasicObject* /*self_*/, BasicObject* h) {
  auto* _g = g_fiber_storage();
  _g->clear_kvps();
  if (h != nil_instance()) {
    auto* _src = static_cast<Hash*>(h);
    _g->copy_kvps_from(*_src);
  }
  return h;
}


}  // namespace Ruby
