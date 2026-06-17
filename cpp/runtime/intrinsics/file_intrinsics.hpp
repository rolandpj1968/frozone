// File-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.
//
// Scope: minimal OS primitives only. Path-string ops (expand/dirname/
// basename/split) and stat-mode predicates live in lib/core/4.0/file.rb;
// they don't need C++. What stays here is the irreducible POSIX surface
// the Ruby side has to call through.

#ifndef FROZONE_FILE_INTRINSICS_HPP
#define FROZONE_FILE_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {


// stat(2) — returns nil on failure, else a 16-element Array. Field
// order matches OS_STAT_* indices in lib/core/4.0/file.rb.
BasicObject* intrinsic_os_stat(BasicObject* path);

// lstat(2) — same shape as os_stat but does not follow symlinks.
BasicObject* intrinsic_os_lstat(BasicObject* path);

// access(2) — mode_bits is R_OK|W_OK|X_OK (any combination of 4/2/1).
BasicObject* intrinsic_os_access(BasicObject* path, BasicObject* mode_bits);

// realpath(3) — returns canonicalised absolute path, or nil on failure
// (e.g. ENOENT). Ruby side translates nil into ENOENT.
BasicObject* intrinsic_os_realpath(BasicObject* path);

// readlink(2) — nil on failure. Buffer sized for PATH_MAX.
BasicObject* intrinsic_os_readlink(BasicObject* path);

// euid/egid for owned?/grpowned? — separate from the eu*id intrinsics in
// process_intrinsics so File doesn't pull in Process namespace.
BasicObject* intrinsic_os_euid();
BasicObject* intrinsic_os_egid();

// Whole-file slurp. Caller (File.read) handles encoding. Returns nil if
// the path can't be opened; the Ruby side maps that to Errno::ENOENT.
BasicObject* intrinsic_file_read(BasicObject* path);

// ---- Mutating POSIX primitives -----------------------------------
// Each returns nil on errno failure; Ruby maps nil → the appropriate
// Errno::* via inspecting errno or trying again.

BasicObject* intrinsic_os_unlink(BasicObject* path);

BasicObject* intrinsic_os_rename(BasicObject* from, BasicObject* to);

BasicObject* intrinsic_os_link(BasicObject* target, BasicObject* link);

BasicObject* intrinsic_os_symlink(BasicObject* target, BasicObject* link);

BasicObject* intrinsic_os_chmod(BasicObject* path, BasicObject* mode);

BasicObject* intrinsic_os_truncate(BasicObject* path, BasicObject* length);

// utimensat with AT_FDCWD; accepts nanosecond-precision atime/mtime.
// flags 0 follows symlinks; AT_SYMLINK_NOFOLLOW for lutime.
BasicObject* intrinsic_os_utimes(BasicObject* path,
                                        BasicObject* atime_sec, BasicObject* atime_nsec,
                                        BasicObject* mtime_sec, BasicObject* mtime_nsec,
                                        BasicObject* follow_symlinks);

BasicObject* intrinsic_os_mkfifo(BasicObject* path, BasicObject* mode);

// umask sets+returns prior mask. nil arg → query (no change). Tricky
// because umask has no "query without change" form; emulate via
// set→reset.
BasicObject* intrinsic_os_umask(BasicObject* new_mask);

BasicObject* intrinsic_os_fnmatch(BasicObject* pattern, BasicObject* path, BasicObject* flags);

// ---- fd-level POSIX primitives -----------------------------------
// Ruby-side IO/File rewrite these as the closed-world IO surface.
// Convention matches the path-level ops above: nil on errno failure,
// caller (Ruby) maps to Errno::* (currently coarse — ENOENT/EIO).

// open(2) — flags is O_RDONLY|O_WRONLY|O_RDWR|O_CREAT|... bitfield;
// mode is the create-mode (e.g. 0644) ignored unless O_CREAT set.
// Returns Integer fd, or nil on failure.
BasicObject* intrinsic_os_open(BasicObject* path, BasicObject* flags, BasicObject* mode);

// close(2) — true on success, nil on failure (EBADF/EIO).
BasicObject* intrinsic_os_close(BasicObject* fd);

// read(2) — up to `len` bytes from `fd` into a fresh binary String.
// Returns the String (possibly shorter than `len`); empty String at EOF;
// nil on errno failure.
BasicObject* intrinsic_os_read(BasicObject* fd, BasicObject* len);

// write(2) — writes the byte content of `bytes` (String) to `fd`.
// Returns Integer byte count written, or nil on errno failure.
BasicObject* intrinsic_os_write(BasicObject* fd, BasicObject* bytes);

// lseek(2) — whence is SEEK_SET|SEEK_CUR|SEEK_END (0|1|2). Returns the
// new offset as Integer, or nil on failure (ESPIPE on pipes/sockets).
BasicObject* intrinsic_os_lseek(BasicObject* fd, BasicObject* offset, BasicObject* whence);

// fstat(2) — same 16-tuple shape as os_stat/os_lstat (OS_STAT_*). nil on
// failure (EBADF on closed fd).
BasicObject* intrinsic_os_fstat(BasicObject* fd);

// isatty(3) — true if fd refers to a terminal, false otherwise. Never
// raises; ENOTTY/EBADF both map to false.
BasicObject* intrinsic_os_isatty(BasicObject* fd);

}  // namespace Ruby

#endif  // FROZONE_FILE_INTRINSICS_HPP
