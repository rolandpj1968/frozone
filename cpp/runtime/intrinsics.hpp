// Box-first Intrinsics implementations.
//
// `Intrinsics.foo(self, args...)` calls in lib/core/4.0/ Ruby code
// lower to inline C++ calls into this header. Each `Intrinsics.X`
// has a corresponding `Ruby::intrinsic_X(...)` inline function here.
//
// Moved out of intrinsic_lowering.rb's string-emitting Ruby lambdas
// for readability and source-size: each intrinsic body lives ONCE
// here (the optimiser inlines as it sees fit), instead of being
// duplicated at every call site as a self-invoking lambda
// expression. Real C++ syntax — editor highlighting, type checking,
// gdb sees real function names.
//
// Forward-declares with full type signatures — must be included
// AFTER the per-program class structs are complete (String*, Array*,
// etc. are referenced via member access). The emitter inserts the
// include between class definitions and method bodies (see
// class_emitter.rb's write_runtime).
//
// Naming: `intrinsic_<ruby_name>` to keep distinct from runtime
// helpers (intern, splat_to_array, ...) which use bare names.
//
// Closure-style intrinsics (kernel_lambda, kernel_proc,
// kernel_block_given) that reference `_block` in the surrounding
// method's scope STAY in intrinsic_lowering.rb — they aren't pure
// functions of their args.

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

// ---- String --------------------------------------------------------

// `String#index(sub, offset = :__unset__)` — find first byte-position
// of sub in self. String sub uses byte memcmp; Regexp sub goes through
// onig_search via regexp_match_helper. Negative offset counts from
// end; offset > size returns nil. Empty needle matches at offset.

// ---- File ----------------------------------------------------------
//
// Enough of `File.*` to let load_core resolve core/4.0/*.rb paths and
// for evaluate_file to read sources. Heavier ops (chmod, link, stat)
// are still abort-stubs — add as needed.

namespace fs_detail {
  inline std::string str_of(BasicObject* o) {
    auto* _s = static_cast<String*>(o);
    return std::string(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size());
  }
  inline BasicObject* string_of(const std::string& s) {
    return new String(s.data(), s.size());
  }
  // Ruby File.expand_path: ~ expansion + abs join + lexical normalisation.
  // We don't go through realpath (so non-existent components are fine)
  // and we don't follow symlinks — that's File.realpath's job.
  inline std::string expand(const std::string& path, const std::string& dir) {
    std::string p = path;
    if (!p.empty() && p[0] == '~') {
      const char* home = std::getenv("HOME");
      if (home) {
        if (p.size() == 1 || p[1] == '/') p = std::string(home) + p.substr(1);
      }
    }
    std::filesystem::path fp(p);
    if (!fp.is_absolute()) {
      std::filesystem::path base = dir.empty() ? std::filesystem::current_path() : std::filesystem::path(dir);
      if (!base.is_absolute()) base = std::filesystem::current_path() / base;
      fp = base / fp;
    }
    fp = fp.lexically_normal();
    // lexically_normal preserves a trailing slash; Ruby strips it.
    std::string out = fp.string();
    if (out.size() > 1 && out.back() == '/') out.pop_back();
    return out;
  }
}

// Many predicates are simple stat-mode checks; consolidate via helper.
namespace fs_detail {
  inline bool stat_check(BasicObject* path, mode_t mask) {
    struct stat st;
    return ::stat(str_of(path).c_str(), &st) == 0 && (st.st_mode & mask);
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
// The legacy Ruby intrinsic (lib/frozone/vm/intrinsics/random_intrinsics.rb,
// used by the interpreted backend) does extensive coercion theatre —
// Rational/Complex/to_int — that's now performed in Ruby-land before
// the call. Box-first's wrappers in lib/core/4.0/random.rb already
// pass concrete Integer/Float/nil/Range, so we keep these narrow.
// Anything weird aborts with a loud message.
//
// `v` (the receiver) is the Random instance for instance methods, or
// nil for the class-method (`Random.rand`, `Random.bytes`) path. The
// generated `Random` struct has no ivars, so per-instance state lives
// in a side-map keyed on the BasicObject* identity. The default
// (nil-receiver) PRNG uses a separate global engine.

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
// Most integer ops are already in TEMPLATES (cpp_box/intrinsic_lowering.rb)
// — __plus_/__minus_/__star_, comparisons, spaceship, bitnot.
// These cover the remaining 13 that lib/core/4.0/integer.rb dispatches
// through Intrinsics.
//
// Box-first stays Int64 throughout. Overflow is undefined behaviour
// today; project_int_soundness.md / project_box_first_overflow_soundness.md
// track the bignum-promotion gap. Where Ruby semantics differ from
// C++ (notably `/` and `%` rounding direction), we apply the Ruby
// adjustment.

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

// Aggregator — pulls all per-category intrinsic headers.
// Per-TU include pruning is a follow-up (task #117 step B); for now
// every TU still gets every category, but the file split lets that
// change cleanly later. Helpers (namespaces, free functions) above
// stay in this file so every per-category header can see them.
#include "intrinsics/dir_intrinsics.hpp"
#include "intrinsics/env_intrinsics.hpp"
#include "intrinsics/file_intrinsics.hpp"
#include "intrinsics/hash_intrinsics.hpp"
#include "intrinsics/integer_intrinsics.hpp"
#include "intrinsics/io_intrinsics.hpp"
#include "intrinsics/kernel_intrinsics.hpp"
#include "intrinsics/object_intrinsics.hpp"
#include "intrinsics/process_intrinsics.hpp"
#include "intrinsics/random_intrinsics.hpp"
#include "intrinsics/regexp_intrinsics.hpp"
#include "intrinsics/string_intrinsics.hpp"

#endif // FROZONE_INTRINSICS_HPP
