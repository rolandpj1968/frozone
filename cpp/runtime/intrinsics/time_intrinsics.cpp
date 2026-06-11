// Time-category intrinsic definitions. Declarations live in
// time_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "time_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

namespace time_detail {
  // strftime into a heap buffer, returns std::string. Grows until fit.
  inline std::string strftime_buf(const char* fmt, const struct tm* tm) {
    std::size_t cap = 64;
    for (int i = 0; i < 6; i++) {
      std::string buf(cap, '\0');
      std::size_t n = ::strftime(&buf[0], cap, fmt, tm);
      if (n > 0) { buf.resize(n); return buf; }
      cap *= 2;
    }
    return std::string();
  }

  // Build the Frozone Array returned by os_localtime / os_gmtime:
  // [sec, min, hour, mday, month_1based, year_full, wday, yday_1based,
  //  isdst, utc_offset_sec, zone_string].
  inline Array* tm_to_array(const struct tm& tm, int32_t utc_offset, const char* zone) {
    Array* arr = new Array();
    arr->data.push_back(new Integer(tm.tm_sec));
    arr->data.push_back(new Integer(tm.tm_min));
    arr->data.push_back(new Integer(tm.tm_hour));
    arr->data.push_back(new Integer(tm.tm_mday));
    arr->data.push_back(new Integer(tm.tm_mon + 1));
    arr->data.push_back(new Integer(tm.tm_year + 1900));
    arr->data.push_back(new Integer(tm.tm_wday));
    arr->data.push_back(new Integer(tm.tm_yday + 1));
    arr->data.push_back(boxed_bool(tm.tm_isdst > 0));
    arr->data.push_back(new Integer(utc_offset));
    arr->data.push_back(new String(zone, std::strlen(zone)));
    return arr;
  }
}

// ---- OS-bound primitives ----------------------------------------------

// os_time_now: [sec, nsec, local_utc_offset_sec] for the current realtime
// clock. Caller (Ruby Time.now) decides whether to wrap as local or UTC.
BasicObject* intrinsic_os_time_now() {
  struct timespec ts;
  ::clock_gettime(CLOCK_REALTIME, &ts);
  time_t s = ts.tv_sec;
  struct tm lt{};
  ::localtime_r(&s, &lt);
  int32_t off;
#ifdef __USE_MISC
  off = static_cast<int32_t>(lt.tm_gmtoff);
#else
  struct tm gt{};
  ::gmtime_r(&s, &gt);
  off = static_cast<int32_t>(::mktime(&gt) - ::mktime(&lt));
#endif
  Array* arr = new Array();
  arr->data.push_back(new Integer(static_cast<int64_t>(ts.tv_sec)));
  arr->data.push_back(new Integer(static_cast<int64_t>(ts.tv_nsec)));
  arr->data.push_back(new Integer(off));
  return arr;
}

BasicObject* intrinsic_os_localtime(BasicObject* sec) {
  time_t s = static_cast<time_t>(static_cast<Integer*>(sec)->raw_);
  struct tm tm{};
  ::localtime_r(&s, &tm);
#ifdef __USE_MISC
  int32_t off = static_cast<int32_t>(tm.tm_gmtoff);
  const char* zone = tm.tm_zone ? tm.tm_zone : "";
#else
  struct tm gt{};
  ::gmtime_r(&s, &gt);
  int32_t off = static_cast<int32_t>(::mktime(&gt) - ::mktime(&tm));
  const char* zone = "";
#endif
  return time_detail::tm_to_array(tm, off, zone);
}

BasicObject* intrinsic_os_gmtime(BasicObject* sec) {
  time_t s = static_cast<time_t>(static_cast<Integer*>(sec)->raw_);
  struct tm tm{};
  ::gmtime_r(&s, &tm);
  return time_detail::tm_to_array(tm, 0, "UTC");
}

// os_mktime: convert calendar fields to epoch sec. utc=true → timegm,
// utc=false → mktime (interprets fields in local timezone). Returns Integer.
BasicObject* intrinsic_os_mktime(BasicObject* year, BasicObject* month,
                                        BasicObject* mday, BasicObject* hour,
                                        BasicObject* min, BasicObject* sec,
                                        BasicObject* use_utc) {
  struct tm tm{};
  tm.tm_year = static_cast<int>(static_cast<Integer*>(year)->raw_) - 1900;
  tm.tm_mon  = static_cast<int>(static_cast<Integer*>(month)->raw_) - 1;
  tm.tm_mday = static_cast<int>(static_cast<Integer*>(mday)->raw_);
  tm.tm_hour = static_cast<int>(static_cast<Integer*>(hour)->raw_);
  tm.tm_min  = static_cast<int>(static_cast<Integer*>(min)->raw_);
  tm.tm_sec  = static_cast<int>(static_cast<Integer*>(sec)->raw_);
  tm.tm_isdst = -1;
  time_t out = (use_utc == true_instance()) ? ::timegm(&tm) : ::mktime(&tm);
  return new Integer(static_cast<int64_t>(out));
}

// os_strftime: format using libc strftime. utc_offset and is_utc determine
// which struct tm we hand to strftime so %Z and %z come out right.
BasicObject* intrinsic_os_strftime(BasicObject* fmt, BasicObject* sec,
                                          BasicObject* utc_offset_sec,
                                          BasicObject* is_utc) {
  int64_t s = static_cast<Integer*>(sec)->raw_;
  int32_t off = static_cast<int32_t>(static_cast<Integer*>(utc_offset_sec)->raw_);
  bool utc = (is_utc == true_instance());
  // For non-UTC, gmtime_r on (s + off) gives the wall-clock fields in the
  // target zone — matches what localtime_r would have produced.
  time_t shifted = static_cast<time_t>(s) + (utc ? 0 : off);
  struct tm tm{};
  ::gmtime_r(&shifted, &tm);
#ifdef __USE_MISC
  tm.tm_gmtoff = utc ? 0 : off;
  tm.tm_zone = const_cast<char*>(utc ? "UTC" : "");
#endif
  std::string format(reinterpret_cast<const char*>(static_cast<String*>(fmt)->bytes.data()),
                     static_cast<String*>(fmt)->bytes.size());
  std::string out = time_detail::strftime_buf(format.c_str(), &tm);
  return new String(out.data(), out.size());
}

// ---- Time struct accessors / constructors ------------------------------
// These remain primitives because they touch the C++ struct layout
// directly. Each is a trivial field read or write.

BasicObject* intrinsic_time_make(BasicObject* sec, BasicObject* nsec,
                                        BasicObject* utc_offset, BasicObject* is_utc) {
  Time* out = new Time();
  out->sec_ = static_cast<Integer*>(sec)->raw_;
  out->nsec_ = static_cast<int32_t>(static_cast<Integer*>(nsec)->raw_);
  out->utc_offset_ = static_cast<int32_t>(static_cast<Integer*>(utc_offset)->raw_);
  out->is_utc_ = (is_utc == true_instance());
  return out;
}

BasicObject* intrinsic_time_to_i(BasicObject* self_) {
  return new Integer(static_cast<Time*>(self_)->sec_);
}

BasicObject* intrinsic_time_nsec(BasicObject* self_) {
  return new Integer(static_cast<Time*>(self_)->nsec_);
}

BasicObject* intrinsic_time_utc_q(BasicObject* self_) {
  return boxed_bool(static_cast<Time*>(self_)->is_utc_);
}

BasicObject* intrinsic_time_utc_offset(BasicObject* self_) {
  auto* t = static_cast<Time*>(self_);
  return new Integer(t->is_utc_ ? 0 : t->utc_offset_);
}

BasicObject* intrinsic_time_utc(BasicObject* self_) {
  auto* t = static_cast<Time*>(self_);
  Time* out = new Time();
  out->sec_ = t->sec_;
  out->nsec_ = t->nsec_;
  out->utc_offset_ = 0;
  out->is_utc_ = true;
  return out;
}

BasicObject* intrinsic_time_dup(BasicObject* self_) {
  auto* t = static_cast<Time*>(self_);
  Time* out = new Time();
  out->sec_ = t->sec_;
  out->nsec_ = t->nsec_;
  out->utc_offset_ = t->utc_offset_;
  out->is_utc_ = t->is_utc_;
  out->iv_frozone_timezone = t->iv_frozone_timezone;
  out->iv_bdt = t->iv_bdt;
  return out;
}

BasicObject* intrinsic_time_localtime(BasicObject* self_, BasicObject* offset) {
  auto* t = static_cast<Time*>(self_);
  Time* out = new Time();
  out->sec_ = t->sec_;
  out->nsec_ = t->nsec_;
  out->is_utc_ = false;
  if (offset && offset != nil_instance() && &typeid(*offset) == &typeid(Integer)) {
    out->utc_offset_ = static_cast<int32_t>(static_cast<Integer*>(offset)->raw_);
  } else {
    time_t s = static_cast<time_t>(t->sec_);
    struct tm tm{};
    ::localtime_r(&s, &tm);
#ifdef __USE_MISC
    out->utc_offset_ = static_cast<int32_t>(tm.tm_gmtoff);
#else
    struct tm gt{};
    ::gmtime_r(&s, &gt);
    out->utc_offset_ = static_cast<int32_t>(::mktime(&gt) - ::mktime(&tm));
#endif
  }
  return out;
}

// ---- Deferred stubs ---------------------------------------------------

BasicObject* intrinsic_time_to_r(BasicObject* /*self_*/) {
  std::fprintf(stderr, "[box-first] time_to_r: Rational construction not yet wired up\n");
  std::abort();
}

BasicObject* intrinsic_time_at_raw(BasicObject* /*r*/, BasicObject* /*offset*/) {
  std::fprintf(stderr, "[box-first] time_at_raw: needs Rational/timezone object support\n");
  std::abort();
}

BasicObject* intrinsic_time_new_from_string(BasicObject* /*str*/, BasicObject* /*prec*/, BasicObject* /*tz*/) {
  std::fprintf(stderr, "[box-first] time_new_from_string: not yet implemented (strptime TODO)\n");
  std::abort();
}

BasicObject* intrinsic_time_dump(BasicObject* /*self_*/) {
  std::fprintf(stderr, "[box-first] time_dump: marshal not yet implemented\n");
  std::abort();
}

BasicObject* intrinsic_time_load(BasicObject* /*str*/) {
  std::fprintf(stderr, "[box-first] time_load: marshal not yet implemented\n");
  std::abort();
}

BasicObject* intrinsic_time_iso8601(BasicObject* /*self_*/, BasicObject* /*frac*/) {
  std::fprintf(stderr, "[box-first] time_iso8601: not yet implemented\n");
  std::abort();
}


}  // namespace Ruby
