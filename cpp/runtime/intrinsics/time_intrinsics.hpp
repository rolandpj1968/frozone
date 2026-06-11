// Time-category intrinsics — minimal OS-bound primitives only.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.
//
// The Time struct (see universe.rb TIME) carries the raw state:
// sec_ (Unix epoch seconds), nsec_ (sub-second nanoseconds 0..999_999_999),
// utc_offset_ (seconds east of UTC for local time), is_utc_ (explicit UTC flag),
// iv_frozone_timezone (Ruby-managed timezone object). All field decomposition
// (year/month/.../arithmetic/format composition) lives in lib/core/4.0/time.rb.
// These primitives expose the truly OS-bound bits: realtime clock,
// localtime_r / gmtime_r breakdown, mktime / timegm, libc strftime.

#ifndef FROZONE_TIME_INTRINSICS_HPP
#define FROZONE_TIME_INTRINSICS_HPP


#include "../intrinsics_helpers.hpp"

namespace Ruby {


// ---- OS-bound primitives ----------------------------------------------

// os_time_now: [sec, nsec, local_utc_offset_sec] for the current realtime
// clock. Caller (Ruby Time.now) decides whether to wrap as local or UTC.
BasicObject* intrinsic_os_time_now();

BasicObject* intrinsic_os_localtime(BasicObject* sec);

BasicObject* intrinsic_os_gmtime(BasicObject* sec);

// os_mktime: convert calendar fields to epoch sec. utc=true → timegm,
// utc=false → mktime (interprets fields in local timezone). Returns Integer.
BasicObject* intrinsic_os_mktime(BasicObject* year, BasicObject* month,
                                        BasicObject* mday, BasicObject* hour,
                                        BasicObject* min, BasicObject* sec,
                                        BasicObject* use_utc);

// os_strftime: format using libc strftime. utc_offset and is_utc determine
// which struct tm we hand to strftime so %Z and %z come out right.
BasicObject* intrinsic_os_strftime(BasicObject* fmt, BasicObject* sec,
                                          BasicObject* utc_offset_sec,
                                          BasicObject* is_utc);

// ---- Time struct accessors / constructors ------------------------------
// These remain primitives because they touch the C++ struct layout
// directly. Each is a trivial field read or write.

BasicObject* intrinsic_time_make(BasicObject* sec, BasicObject* nsec,
                                        BasicObject* utc_offset, BasicObject* is_utc);

BasicObject* intrinsic_time_to_i(BasicObject* self_);

BasicObject* intrinsic_time_nsec(BasicObject* self_);

BasicObject* intrinsic_time_utc_q(BasicObject* self_);

BasicObject* intrinsic_time_utc_offset(BasicObject* self_);

BasicObject* intrinsic_time_utc(BasicObject* self_);

BasicObject* intrinsic_time_dup(BasicObject* self_);

BasicObject* intrinsic_time_localtime(BasicObject* self_, BasicObject* offset);

// ---- Deferred stubs ---------------------------------------------------

BasicObject* intrinsic_time_to_r(BasicObject* /*self_*/);
BasicObject* intrinsic_time_at_raw(BasicObject* /*r*/, BasicObject* /*offset*/);
BasicObject* intrinsic_time_new_from_string(BasicObject* /*str*/, BasicObject* /*prec*/, BasicObject* /*tz*/);
BasicObject* intrinsic_time_dump(BasicObject* /*self_*/);
BasicObject* intrinsic_time_load(BasicObject* /*str*/);
BasicObject* intrinsic_time_iso8601(BasicObject* /*self_*/, BasicObject* /*frac*/);


}  // namespace Ruby

#endif  // FROZONE_TIME_INTRINSICS_HPP
