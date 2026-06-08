// Process-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.

#ifndef FROZONE_PROCESS_INTRINSICS_HPP
#define FROZONE_PROCESS_INTRINSICS_HPP


// `Process.clock_gettime(clock_id, unit = :float_second)` — minimal
// monotonic-clock impl. Ignores `clock_id` (treats every clock as
// MONOTONIC) and supports unit ∈ {:float_second (default), :second,
// :millisecond, :microsecond, :nanosecond}. Returns Float for
// :float_second, Integer otherwise. Sufficient for benchmark probes.
inline BasicObject* intrinsic_process_clock_gettime(BasicObject* /*clock_id*/, BasicObject* unit) {
  auto _now = std::chrono::steady_clock::now().time_since_epoch();
  if (typeid(*unit) == typeid(Symbol)) {
    const char* n = static_cast<Symbol*>(unit)->name_;
    if (std::strcmp(n, "second")      == 0) return new Integer(std::chrono::duration_cast<std::chrono::seconds>(_now).count());
    if (std::strcmp(n, "millisecond") == 0) return new Integer(std::chrono::duration_cast<std::chrono::milliseconds>(_now).count());
    if (std::strcmp(n, "microsecond") == 0) return new Integer(std::chrono::duration_cast<std::chrono::microseconds>(_now).count());
    if (std::strcmp(n, "nanosecond")  == 0) return new Integer(std::chrono::duration_cast<std::chrono::nanoseconds>(_now).count());
  }
  return new Float(std::chrono::duration<double>(_now).count());
}

// ---- Process -------------------------------------------------------
//
// Pure libc passthroughs for the read-only id queries (pid/uid/gid).
// process_kill takes (sig, pid) — sig may be Integer (12) or String
// ("INT"); we cover both. process_clock_getres mirrors the existing
// process_clock_gettime in being clock_id-blind (steady_clock res).
// process_wait* and process_status_* are deferred — they need a
// ProcessStatusObject + GLOBALS["$?"] update path that no current
// caller exercises.

inline BasicObject* intrinsic_process_pid()  { return new Integer(static_cast<int64_t>(::getpid()));  }
inline BasicObject* intrinsic_process_uid()  { return new Integer(static_cast<int64_t>(::getuid()));  }
inline BasicObject* intrinsic_process_euid() { return new Integer(static_cast<int64_t>(::geteuid())); }
inline BasicObject* intrinsic_process_gid()  { return new Integer(static_cast<int64_t>(::getgid()));  }
inline BasicObject* intrinsic_process_egid() { return new Integer(static_cast<int64_t>(::getegid())); }

inline BasicObject* intrinsic_process_groups() {
  int n = ::getgroups(0, nullptr);
  if (n < 0) n = 0;
  std::vector<gid_t> buf(static_cast<std::size_t>(n));
  if (n > 0) ::getgroups(n, buf.data());
  Array* arr = new Array();
  for (gid_t g : buf) arr->data.push_back(new Integer(static_cast<int64_t>(g)));
  return arr;
}

inline BasicObject* intrinsic_process_kill(BasicObject* sig, BasicObject* pid) {
  // Signal: Integer (12) or String/Symbol ("INT", :KILL). Strip
  // optional leading "SIG". A handful of common names are enough for
  // anything self-host frozone runs into; rare names → loud abort.
  int sig_num = 0;
  if (sig->m_class(univ) == reinterpret_cast<BasicObject*>(&Integer_CLASS)) {
    sig_num = static_cast<int>(static_cast<Integer*>(sig)->raw_);
  } else {
    // Accept either String or Symbol — both go to a const char*.
    std::string name;
    if (sig->m_class(univ) == reinterpret_cast<BasicObject*>(&String_CLASS)) {
      name = fs_detail::str_of(sig);
    } else if (typeid(*sig) == typeid(Symbol)) {
      name = static_cast<Symbol*>(sig)->name_;
    } else {
      std::fprintf(stderr, "[box-first] process_kill: unsupported sig type %s\n", sig->ruby_class_name());
      std::abort();
    }
    if (name.rfind("SIG", 0) == 0) name.erase(0, 3);
    if      (name == "HUP")  sig_num = SIGHUP;
    else if (name == "INT")  sig_num = SIGINT;
    else if (name == "QUIT") sig_num = SIGQUIT;
    else if (name == "KILL") sig_num = SIGKILL;
    else if (name == "TERM") sig_num = SIGTERM;
    else if (name == "USR1") sig_num = SIGUSR1;
    else if (name == "USR2") sig_num = SIGUSR2;
    else if (name == "STOP") sig_num = SIGSTOP;
    else if (name == "CONT") sig_num = SIGCONT;
    else if (name == "CHLD") sig_num = SIGCHLD;
    else {
      std::fprintf(stderr, "[box-first] process_kill: signal '%s' not yet mapped\n", name.c_str());
      std::abort();
    }
  }
  // static_cast<Integer*>: pid is a syscall arg, by Ruby convention
  // always Integer; no coercion at this layer.
  ::kill(static_cast<pid_t>(static_cast<Integer*>(pid)->raw_), sig_num);
  return nil_instance();
}

inline BasicObject* intrinsic_process_clock_getres(BasicObject* /*clock_id*/, BasicObject* unit) {
  // steady_clock granularity in nanoseconds; same unit handling as
  // process_clock_gettime above so callers see consistent behaviour.
  using period = std::chrono::steady_clock::period;
  double res_seconds = static_cast<double>(period::num) / static_cast<double>(period::den);
  if (typeid(*unit) == typeid(Symbol)) {
    const char* n = static_cast<Symbol*>(unit)->name_;
    if (std::strcmp(n, "second")      == 0) return new Integer(static_cast<int64_t>(res_seconds));
    if (std::strcmp(n, "millisecond") == 0) return new Integer(static_cast<int64_t>(res_seconds * 1e3));
    if (std::strcmp(n, "microsecond") == 0) return new Integer(static_cast<int64_t>(res_seconds * 1e6));
    if (std::strcmp(n, "nanosecond")  == 0) return new Integer(static_cast<int64_t>(res_seconds * 1e9));
  }
  return new Float(res_seconds);
}

inline BasicObject* intrinsic_process_wait(BasicObject* /*receiver*/, BasicObject* /*pid*/, BasicObject* /*flags*/) {
  std::fprintf(stderr, "[box-first] process_wait not yet supported (needs ProcessStatusObject + $? update)\n");
  std::abort();
}
inline BasicObject* intrinsic_process_wait2(BasicObject* /*receiver*/, BasicObject* /*pid*/, BasicObject* /*flags*/) {
  std::fprintf(stderr, "[box-first] process_wait2 not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_process_waitall(BasicObject* /*receiver*/) {
  std::fprintf(stderr, "[box-first] process_waitall not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_process_status_exitstatus(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] process_status_exitstatus not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_process_status_pid(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] process_status_pid not yet supported\n");
  std::abort();
}
inline BasicObject* intrinsic_process_status_termsig(BasicObject* /*obj*/) {
  std::fprintf(stderr, "[box-first] process_status_termsig not yet supported\n");
  std::abort();
}
#endif  // FROZONE_PROCESS_INTRINSICS_HPP
