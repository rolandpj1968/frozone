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

// Needed for intrinsic_raise_regexp_error — frozone_all.hpp only forward-
// declares eigenclass structs; m_new requires the full definition.
#include "class/RegexpError.hpp"
#include "class/RegexpError_eigenclass.hpp"
// Needed for the uncaught-throw conversion path in intrinsic_kernel_catch.
// We construct a Vm::FrozoneException wrapping the UncaughtThrowError so
// the Vm interpreter's rescue layer (which matches on FrozoneException
// + vm_object, not raw C++ Exception subclasses) can catch and dispatch
// it correctly. AOT-compiled user code would match either form — but the
// interpreter is what's reachable from here.
#include "class/UncaughtThrowError.hpp"
#include "class/UncaughtThrowError_eigenclass.hpp"
#include "class/Frozone_Vm_FrozoneException.hpp"
#include "class/Frozone_Vm_FrozoneException_eigenclass.hpp"

namespace Ruby {

// ---- Kernel --------------------------------------------------------

// CatchFrame — stack-allocated linked-list node, one per live `catch`
// frame on the C++ stack. Each `intrinsic_kernel_catch` pushes a frame
// on entry and pops it on exit (RAII), so the chain at any point
// reflects exactly the set of outer Ruby `catch` blocks visible to a
// throw. Lets us answer "could any outer catch match this tag?" via
// a tiny pointer walk — without that knowledge we couldn't tell
// "matched higher up" from "no catcher anywhere", and we'd have to
// either let ThrownTag escape user code (terminate) or convert too
// eagerly (breaking nested catch). thread_local so future Fiber/Thread
// support gets per-fiber chains for free.
struct CatchFrame {
  BasicObject* tag_;
  CatchFrame* prev_;
  explicit CatchFrame(BasicObject* tag) : tag_(tag), prev_(top_) { top_ = this; }
  ~CatchFrame() { top_ = prev_; }
  CatchFrame(const CatchFrame&) = delete;
  CatchFrame& operator=(const CatchFrame&) = delete;
  static thread_local CatchFrame* top_;
};
thread_local CatchFrame* CatchFrame::top_ = nullptr;

// Convert an uncaught throw to UncaughtThrowError, wrapped in a
// FrozoneException so the Vm interpreter's rescue dispatch can match
// it. The UncaughtThrowError carries @tag and @value (set by its Ruby
// initializer); the FrozoneException carries the inner instance as
// @vm_object + the message for `e.message` introspection. Same
// include-set pattern as intrinsic_raise_regexp_error.
[[noreturn]] static void raise_uncaught_throw_(BasicObject* tag, BasicObject* value) {
  auto* _uct = (&UncaughtThrowError_CLASS)->m_new(univ, new Array({tag, value}));
  auto* _msg = static_cast<Exception*>(_uct)->iv_message;
  throw static_cast<Exception*>((&Frozone_Vm_FrozoneException_CLASS)->m_new(univ, new Array({_uct, _msg})));
}

// `catch(tag) { |t| ... }` — wraps the block in try/catch matching on
// ThrownTag's identity tag (Symbols intern, so == is correct). Block
// receives the tag as its sole argument.
//
// On mismatch, walk the outer CatchFrame chain: if any outer catch
// would match the thrown tag, rethrow ThrownTag so that catch sees
// it. If no outer match exists, convert to UncaughtThrowError — a
// real Ruby Exception subclass that `rescue` clauses (compiled to
// `catch (Exception*)`) and matchers like `raise_error(ArgumentError)`
// can intercept. Mirrors MRI's `throw → UncaughtThrowError when no
// catcher` semantics, in one place rather than per-rescue codegen.
BasicObject* intrinsic_kernel_catch(BasicObject* /*self_*/, BasicObject* tag, BasicObject* block) {
  CatchFrame _frame(tag);
  try {
    return static_cast<Proc*>(block)->m_call(univ, new Array({tag}));
  } catch (ThrownTag* _t) {
    if (_t->tag_ == tag) return _t->value_;
    for (auto* _outer = _frame.prev_; _outer; _outer = _outer->prev_) {
      if (_outer->tag_ == _t->tag_) throw;
    }
    raise_uncaught_throw_(_t->tag_, _t->value_);
  }
}

// RegexpError raiser used by gen'd Regexp::m_initialize. Built here
// (not at the call-site) so the calling TU doesn't need RegexpError's
// full class graph in its include set.
void intrinsic_raise_regexp_error(const char* msg, std::size_t len) {
  auto* _msg = new String(msg, len);
  throw static_cast<Exception*>((&RegexpError_CLASS)->m_new(univ, new Array({_msg})));
}

// `Intrinsics.dbg_write(str)` — bespoke raw-write to stderr for AOT-mode
// debugging. Bypasses ALL Ruby dispatch (no Symbol#to_s, no IO#puts, no
// $stdout introspection). Direct fputs(stderr) of the String's bytes +
// fflush so output appears immediately even on abort. Use when the
// regular puts chain is broken (e.g. during dispatch-table bring-up).
BasicObject* intrinsic_dbg_write(BasicObject* /*self_*/, BasicObject* s) {
  if (s->typeid_eq_q<String>()) {
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
  if (val->typeid_eq_q<Integer>()) return new Float(static_cast<double>(static_cast<Integer*>(val)->raw_));
  if (val->typeid_eq_q<Float>()) return val;
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
