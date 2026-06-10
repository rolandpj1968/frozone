// Box-first Intrinsics implementations.
//
// `Intrinsics.X(self, args...)` in lib/core/4.0/ Ruby code lowers to
// an inline call to `Ruby::intrinsic_X(...)` defined in this header
// (or one of the per-category headers it aggregates).
//
// Bodies depend on the per-program class structs (String*, Array*,
// ...) being complete, so the emitter inserts this include between
// the class definitions and the method bodies.
//
// Naming: `intrinsic_<ruby_name>` to stay distinct from bare-named
// runtime helpers (intern, splat_to_array, ...).
//
// Closure-style intrinsics (kernel_lambda, kernel_proc,
// kernel_block_given) that capture `_block` in the surrounding
// method's scope stay in intrinsic_lowering.rb instead — they aren't
// pure functions of their args.

// NB: This header is `#include`'d INSIDE the gen file's
// `namespace Ruby { ... }` block (see class_emitter.rb), so the
// declarations below land directly in namespace Ruby. Do NOT add a
// `namespace Ruby { ... }` wrapper here — it would create
// `Ruby::Ruby::intrinsic_X` and break callers.

#ifndef FROZONE_INTRINSICS_HPP
#define FROZONE_INTRINSICS_HPP

// (Includes for stdlib/POSIX headers used here live in box_first.hpp,
// since this file is `#include`d inside `namespace Ruby { ... }` and
// nesting <csignal>/<unistd.h> there breaks symbol resolution.)

// Loud stub for a reachable-but-deliberately-unimplemented intrinsic.
// IntrinsicLowering emits a call to this for names in STUB_INTRINSICS,
// so the method compiles (and is reached/dispatched normally) but a hit
// aborts loudly with the name instead of silently falling through to
// method_missing. [[noreturn]] keeps the enclosing method's control-flow
// analysis clean (no -Wreturn-type) despite the BasicObject* return type.
[[noreturn]] inline BasicObject* intrinsic_not_implemented(const char* name) {
  std::fprintf(stderr, "[box-first] intrinsic %s not implemented (reachable stub)\n", name);
  std::abort();
}

// Kernel#exit / exit! raise this; it propagates through method try/catch
// (which only catch ReturnException/Exception*) and EnsureGuard (so
// `ensure` blocks still run during unwinding), and frozone_main_impl
// catches it to terminate with the requested status.
struct SystemExitException { std::int64_t status; };

// ---- File-system shared helpers -----------------------------------
//
// String <-> BasicObject* conversion used by every category that takes
// path arguments (file_, dir_, env_). File predicates and path ops live
// in lib/core/4.0/file.rb on top of os_stat/os_access/os_realpath
// primitives in intrinsics/file_intrinsics.hpp.

namespace fs_detail {
  inline std::string str_of(BasicObject* o) {
    auto* _s = static_cast<String*>(o);
    return std::string(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size());
  }
  inline BasicObject* string_of(const std::string& s) {
    return new String(s.data(), s.size());
  }
}

// ---- ENV -----------------------------------------------------------
//
// Thin wrappers over getenv/setenv/unsetenv + walks of POSIX
// `environ`. lib/core/4.0/env.rb does all the encoding wrapping,
// validation, and Hash-like sugar; we just supply raw String values
// (or nil for absent keys) and bool predicates.

extern "C" char **environ;

namespace env_detail {
  inline BasicObject* string_of(const char* s, std::size_t n) {
    return new String(s, n);
  }
  inline BasicObject* string_of(const char* s) { return string_of(s, std::strlen(s)); }
}

// ---- Random --------------------------------------------------------
//
// `v` (the receiver) is the Random instance for instance methods, or
// nil for the class-method (`Random.rand`, `Random.bytes`) path. The
// generated `Random` struct has no ivars, so per-instance state lives
// in a side-map keyed on the BasicObject* identity. The default
// (nil-receiver) PRNG uses a separate global engine.
//
// Coercion (Rational/Complex/to_int) happens in core/4.0/random.rb
// before the call lands here; these wrappers stay narrow.

namespace random_detail {
  inline std::mt19937_64& default_rng() {
    static std::mt19937_64 rng{std::random_device{}()};
    return rng;
  }
  inline std::uint64_t fresh_seed() {
    static std::random_device rd;
    return (static_cast<std::uint64_t>(rd()) << 32) | static_cast<std::uint64_t>(rd());
  }
  // (engine, original_seed) keyed by Random*. Original seed is what
  // Random#seed returns — mt19937_64 doesn't expose recoverable seed,
  // so we remember what we initialised with.
  struct Slot { std::mt19937_64 engine; std::uint64_t seed; };
  inline std::unordered_map<BasicObject*, Slot>& per_obj() {
    static std::unordered_map<BasicObject*, Slot> m;
    return m;
  }
  inline Slot& slot_for(BasicObject* v, std::uint64_t default_seed) {
    auto& m = per_obj();
    auto it = m.find(v);
    if (it != m.end()) return it->second;
    return m.emplace(v, Slot{std::mt19937_64{default_seed}, default_seed}).first->second;
  }
  inline std::mt19937_64& rng_for(BasicObject* v) {
    if (v == nil_instance()) return default_rng();
    return slot_for(v, fresh_seed()).engine;
  }
}

// ---- Integer -------------------------------------------------------
//
// Box-first stays Int64 throughout. Where Ruby semantics differ from
// C++ (notably `/` and `%` rounding direction) the helpers below apply
// the Ruby adjustment. Most arithmetic ops lower via TEMPLATES in
// cpp_box/intrinsic_lowering.rb; the bodies here cover what doesn't
// fit a single-expression template.

namespace integer_detail {
  // Ruby `/` rounds toward negative infinity; C++ truncates toward
  // zero. Adjust quotient when signs differ and there's a remainder.
  inline int64_t ruby_div(int64_t a, int64_t b) {
    int64_t q = a / b;
    if ((a % b != 0) && ((a < 0) != (b < 0))) q -= 1;
    return q;
  }
  // Ruby `%` returns a result with the divisor's sign. C++'s `%`
  // returns a result with the dividend's sign. Adjust by adding
  // divisor when signs differ.
  inline int64_t ruby_mod(int64_t a, int64_t b) {
    int64_t r = a % b;
    if (r != 0 && ((r < 0) != (b < 0))) r += b;
    return r;
  }
}

// Aggregator — pulls all per-category intrinsic headers. Helpers
// (namespaces, free functions) above stay in this file so every
// per-category header can see them.
#include "intrinsics/dir_intrinsics.hpp"
#include "intrinsics/env_intrinsics.hpp"
#include "intrinsics/file_intrinsics.hpp"
#include "intrinsics/float_intrinsics.hpp"
#include "intrinsics/hash_intrinsics.hpp"
#include "intrinsics/integer_intrinsics.hpp"
#include "intrinsics/io_intrinsics.hpp"
#include "intrinsics/kernel_intrinsics.hpp"
#include "intrinsics/object_intrinsics.hpp"
#include "intrinsics/process_intrinsics.hpp"
#include "intrinsics/random_intrinsics.hpp"
#include "intrinsics/regexp_intrinsics.hpp"
#include "intrinsics/string_intrinsics.hpp"
#include "intrinsics/time_intrinsics.hpp"

#endif // FROZONE_INTRINSICS_HPP
