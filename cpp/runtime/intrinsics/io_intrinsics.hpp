// Io-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_IO_INTRINSICS_HPP
#define FROZONE_IO_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {

// Raw write to stdout/stderr — direct fwrite, no dispatch chain.
// Used by box-first compiled `io_write` when the receiver IOObject's
// @native_io is nil (chicken-egg: GLOBALS["$stdout"] is set at vm.rb
// bootstrap to IOObject.new(nil, …, stream_tag: :stdout), so the
// stream identity lives on the IOObject's @stream_tag ivar). The
// Ruby io_write detects native.nil? and routes here based on the tag.
// Return value: byte count written (Integer).
BasicObject* intrinsic_io_raw_write_stdout(BasicObject* /*self_*/, BasicObject* s);

BasicObject* intrinsic_io_raw_write_stderr(BasicObject* /*self_*/, BasicObject* s);

// `IO.popen(cmd, mode='r', opts=nil)` — fork+exec+pipe, return an IO
// bound to the child's stdout via @fd. Mode 'r' only (mspec/ruby_exe
// reads the child output). cmd may be a String (shell exec via sh -c) or
// an Array of Strings (direct execvp). opts is ignored — env/chdir/etc.
// not modelled. Throws SystemCallError on syscall failure, ArgumentError
// on bad cmd shape. Klass arg ignored; the result is always plain IO.
BasicObject* intrinsic_io_popen(BasicObject* /*klass*/, BasicObject* cmd,
                                BasicObject* mode, BasicObject* opts);

}  // namespace Ruby

#endif  // FROZONE_IO_INTRINSICS_HPP
