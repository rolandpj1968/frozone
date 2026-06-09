// Kernel-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_KERNEL_INTRINSICS_HPP
#define FROZONE_KERNEL_INTRINSICS_HPP


// ---- Kernel --------------------------------------------------------

// `catch(tag) { |t| ... }` — wraps the block in try/catch matching on
// ThrownTag's identity tag (Symbols intern, so == is correct). Block
// receives the tag as its sole argument.
inline BasicObject* intrinsic_kernel_catch(BasicObject* /*self_*/, BasicObject* tag, BasicObject* block) {
  try {
    return static_cast<Proc*>(block)->m_call(univ, new Array({tag}));
  } catch (ThrownTag* _t) {
    if (_t->tag_ == tag) return _t->value_;
    throw;
  }
}

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
inline BasicObject* intrinsic_dbg_write(BasicObject* /*self_*/, BasicObject* s) {
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
inline BasicObject* intrinsic_kernel_puts(BasicObject* /*self_*/, BasicObject* args_arr) {
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
inline BasicObject* intrinsic_kernel_print(BasicObject* /*self_*/, BasicObject* args_arr) {
  auto* _a = splat_to_array(args_arr);
  for (auto* _e : _a->data) ruby_puts(_e);
  return nil_instance();
}

// `Kernel#rand(n)` — global PRNG. Stub: route through a process-wide
// Random instance (deterministically seeded with 0). Real impl would
// seed with /dev/urandom.
inline BasicObject* intrinsic_kernel_rand(BasicObject* /*self_*/, BasicObject* n) {
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
inline BasicObject* intrinsic_kernel_integer(BasicObject* /*self_*/, BasicObject* val,
                                             BasicObject* /*base*/, BasicObject* /*exception*/) {
  return new Integer(coerce_to_int(val));
}

// `Kernel#Float(val)` — coerce to Float. Fast path for Integer/Float;
// else dispatches to_f.
inline BasicObject* intrinsic_kernel_float(BasicObject* /*self_*/, BasicObject* val) {
  if (&typeid(*val) == &typeid(Integer)) return new Float(static_cast<double>(static_cast<Integer*>(val)->raw_));
  if (&typeid(*val) == &typeid(Float)) return val;
  return val->m_to_f(univ);
}

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
inline BasicObject* intrinsic_fiber_storage_get(BasicObject* /*self_*/, BasicObject* key) {
  auto& _h = g_fiber_storage()->data;
  auto _it = _h.find(key);
  return (_it == _h.end()) ? nil_instance() : _it->second;
}

// `Fiber[:k] = v` — write to process-global storage Hash.
inline BasicObject* intrinsic_fiber_storage_set(BasicObject* /*self_*/, BasicObject* key, BasicObject* val) {
  g_fiber_storage()->put(key, val);
  return val;
}
#endif  // FROZONE_KERNEL_INTRINSICS_HPP
