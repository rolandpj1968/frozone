// Shared helpers used by multiple intrinsic categories.
//
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.
//
// `#include "intrinsics_helpers.hpp"` from any per-category
// `intrinsics/X_intrinsics.hpp` that needs `fs_detail`, the
// `intrinsic_not_implemented` stub, or `SystemExitException`.

#ifndef FROZONE_INTRINSICS_HELPERS_HPP
#define FROZONE_INTRINSICS_HELPERS_HPP

namespace Ruby {

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

// String <-> BasicObject* conversion used by every category that takes
// path arguments (file_, dir_, env_, process_, string_).
namespace fs_detail {
  inline std::string str_of(BasicObject* o) {
    auto* _s = static_cast<String*>(o);
    return std::string(reinterpret_cast<const char*>(_s->bytes.data()), _s->bytes.size());
  }
  inline BasicObject* string_of(const std::string& s) {
    return new String(s.data(), s.size());
  }
}

}  // namespace Ruby

#endif  // FROZONE_INTRINSICS_HELPERS_HPP
