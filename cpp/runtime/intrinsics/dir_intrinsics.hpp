// Dir-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_DIR_INTRINSICS_HPP
#define FROZONE_DIR_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {

// ---- Dir -----------------------------------------------------------
//
// POSIX opendir/readdir/stat instead of std::filesystem — the latter
// crashes at -O2 when libstdc++.so's internal free() runs on a Boehm-
// allocated buffer (see box_first.hpp for the full rationale).
// dir_open/read/close/seek hold a per-instance DIR* off the generated
// `Dir` struct (no @dir_handle ivar yet) so those abort loudly.
// dir_glob, dir_chdir, dir_pwd, dir_home, dir_entries, dir_mkdir/rmdir,
// dir_exist/empty cover the path-based queries that frozone itself uses.

BasicObject* intrinsic_dir_pwd();

BasicObject* intrinsic_dir_chdir(BasicObject* path, BasicObject* block);

BasicObject* intrinsic_dir_home(BasicObject* user);

BasicObject* intrinsic_dir_entries(BasicObject* path);


BasicObject* intrinsic_dir_glob(BasicObject* pattern, BasicObject* /*flags*/, BasicObject* /*base*/, BasicObject* /*sort*/);

BasicObject* intrinsic_dir_mkdir(BasicObject* path, BasicObject* /*perm*/);

BasicObject* intrinsic_dir_rmdir(BasicObject* path);

BasicObject* intrinsic_dir_exist(BasicObject* path);

BasicObject* intrinsic_dir_empty(BasicObject* path);

// Per-instance DIR* state — the generated Dir struct has no slot
// for it, so attempting to use these from Ruby aborts. Listed for
// completeness of HPP_INTRINSICS coverage.
BasicObject* intrinsic_dir_open(BasicObject* /*path*/);
BasicObject* intrinsic_dir_close(BasicObject* /*obj*/);
BasicObject* intrinsic_dir_read(BasicObject* /*obj*/);
BasicObject* intrinsic_dir_seek(BasicObject* /*obj*/, BasicObject* /*pos*/);
BasicObject* intrinsic_dir_rewind(BasicObject* /*obj*/);
BasicObject* intrinsic_dir_fileno(BasicObject* /*obj*/);
BasicObject* intrinsic_dir_for_fd(BasicObject* /*fd*/);
BasicObject* intrinsic_dir_fchdir(BasicObject* /*fd*/, BasicObject* /*block*/);
BasicObject* intrinsic_dir_chroot(BasicObject* /*path*/);
// Dir.mktmpdir hoisted to Ruby on top of os_mkdtemp (POSIX mkdtemp(3)).
BasicObject* intrinsic_os_mkdtemp(BasicObject* /*template*/);

}  // namespace Ruby

#endif  // FROZONE_DIR_INTRINSICS_HPP
