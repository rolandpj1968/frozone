// Env-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.
//
// Minimal surface: getenv/setenv/unsetenv + a single walk of POSIX
// `environ` returning an Array of [key, value] String pairs. All
// Hash-shape logic (keys, values, key?, value?, to_h, clear, …) lives
// in lib/core/4.0/env.rb on top of these four primitives.

#ifndef FROZONE_ENV_INTRINSICS_HPP
#define FROZONE_ENV_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

extern "C" char **environ;

namespace Ruby {


BasicObject* intrinsic_os_getenv(BasicObject* key);

BasicObject* intrinsic_os_setenv(BasicObject* key, BasicObject* value);

BasicObject* intrinsic_os_unsetenv(BasicObject* key);

BasicObject* intrinsic_os_environ_pairs();


}  // namespace Ruby

#endif  // FROZONE_ENV_INTRINSICS_HPP
