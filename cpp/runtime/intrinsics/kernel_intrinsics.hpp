// Kernel-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_KERNEL_INTRINSICS_HPP
#define FROZONE_KERNEL_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Kernel --------------------------------------------------------

// `catch(tag) { |t| ... }` — wraps the block in try/catch matching on
// ThrownTag's identity tag (Symbols intern, so == is correct). Block
// receives the tag as its sole argument.
BasicObject* intrinsic_kernel_catch(BasicObject* /*self_*/, BasicObject* tag, BasicObject* block);

// `throw tag, value` — raises a ThrownTag carrying both. Caller
// nil-defaults the value at the Ruby level.
[[noreturn]] inline BasicObject* intrinsic_kernel_throw(BasicObject* /*self_*/, BasicObject* tag, BasicObject* value) {
  throw new ThrownTag(tag, value);
}

// `Intrinsics.dbg_write(str)` — bespoke raw-write to stderr for AOT-mode
// debugging. Bypasses ALL Ruby dispatch (no Symbol#to_s, no IO#puts, no
// $stdout introspection). Direct fputs(stderr) of the String's bytes +
// fflush so output appears immediately even on abort. Use when the
// regular puts chain is broken (e.g. during dispatch-table bring-up).
BasicObject* intrinsic_dbg_write(BasicObject* /*self_*/, BasicObject* s);

// `Kernel#puts(*args)` via send/dynamic dispatch (direct `puts` already
// routes through ruby_puts at the call-site).
BasicObject* intrinsic_kernel_puts(BasicObject* /*self_*/, BasicObject* args_arr);

// `Kernel#print(*args)` — puts without trailing newline. Stub: route
// through ruby_puts (mismatch, but rarely visible).
BasicObject* intrinsic_kernel_print(BasicObject* /*self_*/, BasicObject* args_arr);

// `Kernel#rand(n)` — global PRNG. Stub: route through a process-wide
// Random instance (deterministically seeded with 0). Real impl would
// seed with /dev/urandom.
BasicObject* intrinsic_kernel_rand(BasicObject* /*self_*/, BasicObject* n);

// `Kernel#Integer(val, base = nil, exception: true)` — coerce to
// Integer via existing helper.
BasicObject* intrinsic_kernel_integer(BasicObject* /*self_*/, BasicObject* val,
                                             BasicObject* /*base*/, BasicObject* /*exception*/);

// `Kernel#Float(val)` — coerce to Float. Fast path for Integer/Float;
// else dispatches to_f.
BasicObject* intrinsic_kernel_float(BasicObject* /*self_*/, BasicObject* val);

// `Kernel#raise(msg, message, backtrace, cause)`. Common forms: 1-arg
// (`raise X` or `raise "msg"`) and 2-arg (`raise X, "msg"`); 3+ arg
// backtrace/cause variants are rare and treated the same here.
[[noreturn]] inline BasicObject* intrinsic_kernel_raise(BasicObject* /*self_*/, BasicObject* msg, BasicObject* message,
                                                       BasicObject* /*backtrace*/, BasicObject* /*cause*/) {
  BasicObject* _exc;
  if (msg->mm_is_a_q_direct(&Class_CLASS)) {
    auto* _k = static_cast<Class*>(msg);
    _exc = (message == nil_instance()) ? _k->m_new(univ) : _k->m_new(univ, new Array({message}));
  } else if (msg->mm_is_a_q_direct(&Exception_CLASS)) {
    _exc = msg;
  } else {
    _exc = (&RuntimeError_CLASS)->m_new(univ, new Array({msg}));
  }
  throw static_cast<Exception*>(_exc);
}

// `Kernel#exit(code)` — code is true (status 0), false (status 1), or an
// Integer status (the Ruby wrapper __kernel_exit__ coerces other types).
// Throws SystemExitException; ensures unwind via EnsureGuard and
// frozone_main_impl converts it to the process exit status.
[[noreturn]] inline BasicObject* intrinsic_kernel_exit(BasicObject* /*self_*/, BasicObject* code) {
  std::int64_t _status = 0;
  if (code == false_instance()) _status = 1;
  else if (&typeid(*code) == &typeid(Integer)) _status = static_cast<Integer*>(code)->raw_;
  std::fflush(stdout);
  std::fflush(stderr);
  throw SystemExitException{_status};
}

// ---- Fiber storage -------------------------------------------------

// `Fiber[:k]` — read from process-global storage Hash. Symbols intern
// so identity-keyed access is correct. Direct ->data avoids the
// universal op_aref/op_aset Array allocation.
BasicObject* intrinsic_fiber_storage_get(BasicObject* /*self_*/, BasicObject* key);

// `Fiber[:k] = v` — write to process-global storage Hash.
BasicObject* intrinsic_fiber_storage_set(BasicObject* /*self_*/, BasicObject* key, BasicObject* val);

}  // namespace Ruby

#endif  // FROZONE_KERNEL_INTRINSICS_HPP
