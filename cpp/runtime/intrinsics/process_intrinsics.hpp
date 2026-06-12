// Process-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_PROCESS_INTRINSICS_HPP
#define FROZONE_PROCESS_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {

// `Process.clock_gettime(clock_id, unit = :float_second)` — minimal
// monotonic-clock impl. Ignores `clock_id` (treats every clock as
// MONOTONIC) and supports unit ∈ {:float_second (default), :second,
// :millisecond, :microsecond, :nanosecond}. Returns Float for
// :float_second, Integer otherwise. Sufficient for benchmark probes.
BasicObject* intrinsic_process_clock_gettime(BasicObject* /*clock_id*/, BasicObject* unit);

// ---- Process -------------------------------------------------------
//
// Pure libc passthroughs for the read-only id queries (pid/uid/gid).
// process_kill takes (sig, pid) — sig may be Integer (12) or String
// ("INT"); we cover both. process_clock_getres mirrors the existing
// process_clock_gettime in being clock_id-blind (steady_clock res).
// process_wait* and process_status_* are deferred — they need a
// ProcessStatusObject + GLOBALS["$?"] update path that no current
// caller exercises.

BasicObject* intrinsic_process_pid();
BasicObject* intrinsic_process_uid();
BasicObject* intrinsic_process_euid();
BasicObject* intrinsic_process_gid();
BasicObject* intrinsic_process_egid();

BasicObject* intrinsic_process_groups();

BasicObject* intrinsic_process_kill(BasicObject* sig, BasicObject* pid);

BasicObject* intrinsic_process_clock_getres(BasicObject* /*clock_id*/, BasicObject* unit);

// process_wait*, process_status_* hoisted to Ruby — see core/4.0/process.rb.
// Only the thin POSIX wrapper remains here.
BasicObject* intrinsic_os_waitpid(BasicObject* pid, BasicObject* flags);

}  // namespace Ruby

#endif  // FROZONE_PROCESS_INTRINSICS_HPP
