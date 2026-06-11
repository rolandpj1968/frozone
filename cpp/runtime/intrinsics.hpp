// Box-first Intrinsics implementations — aggregator.
//
// `Intrinsics.X(self, args...)` in lib/core/4.0/ Ruby code lowers to
// an inline call to `Ruby::intrinsic_X(...)` defined in one of the
// per-category headers under `intrinsics/`. Each category header
// self-wraps `namespace Ruby { ... }` and is safe to `#include` at
// TU file scope.
//
// This aggregator is included by TUs that genuinely need the whole
// surface (frozone_main_impl, the universe TU). Per-class TUs include
// only the categories their bodies actually call — emitted by
// class_emitter.rb from collect_call_surface's intrinsic ref table.
//
// Shared helpers (`fs_detail`, `intrinsic_not_implemented`,
// `SystemExitException`) live in `intrinsics_helpers.hpp`. Each
// category header pulls it directly when needed.
//
// Bodies depend on the per-program class structs (String*, Array*,
// ...) being complete, so this is included AFTER the class
// definitions.
//
// Naming: `intrinsic_<ruby_name>` to stay distinct from bare-named
// runtime helpers (intern, splat_to_array, ...).
//
// Closure-style intrinsics (kernel_lambda, kernel_proc,
// kernel_block_given) that capture `_block` in the surrounding
// method's scope stay in intrinsic_lowering.rb instead — they aren't
// pure functions of their args.

#ifndef FROZONE_INTRINSICS_HPP
#define FROZONE_INTRINSICS_HPP

// (Includes for stdlib/POSIX headers used by per-category bodies
// live in box_first.hpp, since the category headers self-wrap
// `namespace Ruby { ... }` and nesting `<csignal>`/`<unistd.h>`
// inside that namespace would break libc symbol resolution.)

#include "intrinsics_helpers.hpp"

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

#endif  // FROZONE_INTRINSICS_HPP
