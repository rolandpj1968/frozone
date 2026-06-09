// Time-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.
//
// Time state lives in native fields on the Time struct (see
// universe.rb TIME): sec_ (Unix epoch seconds), nsec_ (sub-second
// nanoseconds 0..999_999_999), utc_offset_ (seconds east of UTC for
// local time), is_utc_ (explicit UTC flag), iv_frozone_timezone
// (Ruby-managed timezone object). Breakdowns (year/month/...) use
// localtime_r / gmtime_r on demand.
//
// MVP scope: now, accessors, to_i / to_f / to_s, inspect, utc, utc?,
// utc_offset, dup, asctime, strftime, plus/minus, ceil/floor/round.
// Time.at-style construction via time_at_from_int_float (no Rational
// round-trip yet). Rational-bearing entry points (to_r, time_at_raw)
// and parse/marshal/mktime-full abort with a clear message.

#ifndef FROZONE_TIME_INTRINSICS_HPP
#define FROZONE_TIME_INTRINSICS_HPP

namespace time_detail {
  // Break sec_+utc_offset_ down to struct tm. UTC path uses gmtime_r
  // on (sec_ + utc_offset_) — gmtime_r gives the tm fields as if the
  // shifted timestamp were UTC, which is exactly the "local-time"
  // breakdown we want for non-UTC Time. is_utc_ → just gmtime_r(sec_).
  inline struct tm to_tm(const Time* t) {
    time_t s = static_cast<time_t>(t->sec_) + (t->is_utc_ ? 0 : t->utc_offset_);
    struct tm out{};
    ::gmtime_r(&s, &out);
    return out;
  }

  // strftime into a heap buffer, returns std::string. Grows until fit.
  inline std::string strftime_local(const char* fmt, const struct tm* tm) {
    std::size_t cap = 64;
    for (int i = 0; i < 6; i++) {
      std::string buf(cap, '\0');
      std::size_t n = ::strftime(&buf[0], cap, fmt, tm);
      if (n > 0) { buf.resize(n); return buf; }
      cap *= 2;
    }
    return std::string();
  }

  // Default to_s / inspect format: "2024-01-15 12:34:56 +0000".
  inline std::string default_format(const Time* t) {
    struct tm tm = to_tm(t);
    char buf[64];
    int off = t->is_utc_ ? 0 : t->utc_offset_;
    int hh = off / 3600, mm = (std::abs(off) % 3600) / 60;
    std::snprintf(buf, sizeof(buf),
                  "%04d-%02d-%02d %02d:%02d:%02d %+03d%02d",
                  tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
                  tm.tm_hour, tm.tm_min, tm.tm_sec, hh, mm);
    return std::string(buf);
  }
}

inline BasicObject* intrinsic_time_now() {
  struct timespec ts;
  ::clock_gettime(CLOCK_REALTIME, &ts);
  Time* t = new Time();
  t->sec_ = static_cast<int64_t>(ts.tv_sec);
  t->nsec_ = static_cast<int32_t>(ts.tv_nsec);
  // Default to local time — compute offset via localtime/gmtime delta.
  struct tm lt{}, gt{};
  time_t s = ts.tv_sec;
  ::localtime_r(&s, &lt);
  ::gmtime_r(&s, &gt);
  // lt.tm_gmtoff is glibc extension; fall back to delta if not present.
#ifdef __USE_MISC
  t->utc_offset_ = static_cast<int32_t>(lt.tm_gmtoff);
#else
  t->utc_offset_ = static_cast<int32_t>(::mktime(&gt) - ::mktime(&lt));
#endif
  t->is_utc_ = false;
  return t;
}

inline BasicObject* intrinsic_time_to_i(BasicObject* self_) {
  return new Integer(static_cast<Time*>(self_)->sec_);
}

inline BasicObject* intrinsic_time_to_f(BasicObject* self_) {
  auto* t = static_cast<Time*>(self_);
  return new Float(static_cast<double>(t->sec_) + static_cast<double>(t->nsec_) / 1e9);
}

inline BasicObject* intrinsic_time_to_s(BasicObject* self_) {
  std::string s = time_detail::default_format(static_cast<Time*>(self_));
  return new String(s.data(), s.size());
}

inline BasicObject* intrinsic_time_inspect(BasicObject* self_) {
  auto* t = static_cast<Time*>(self_);
  std::string s = time_detail::default_format(t);
  if (t->nsec_ != 0) {
    // Insert ".NNNNNN" after seconds (before " +0000").
    char buf[16];
    std::snprintf(buf, sizeof(buf), ".%09d", t->nsec_);
    std::string ns(buf);
    // strip trailing zeros, but keep at least one digit
    while (ns.size() > 2 && ns.back() == '0') ns.pop_back();
    auto sp = s.find(' ', s.find(' ') + 1);  // 2nd space (before timezone)
    if (sp != std::string::npos) s.insert(sp, ns);
  }
  if (t->is_utc_) {
    auto last_sp = s.rfind(' ');
    if (last_sp != std::string::npos) s.replace(last_sp + 1, std::string::npos, "UTC");
  }
  return new String(s.data(), s.size());
}

inline BasicObject* intrinsic_time_sec(BasicObject* self_) {
  struct tm tm = time_detail::to_tm(static_cast<Time*>(self_));
  return new Integer(tm.tm_sec);
}

inline BasicObject* intrinsic_time_min(BasicObject* self_) {
  struct tm tm = time_detail::to_tm(static_cast<Time*>(self_));
  return new Integer(tm.tm_min);
}

inline BasicObject* intrinsic_time_hour(BasicObject* self_) {
  struct tm tm = time_detail::to_tm(static_cast<Time*>(self_));
  return new Integer(tm.tm_hour);
}

inline BasicObject* intrinsic_time_mday(BasicObject* self_) {
  struct tm tm = time_detail::to_tm(static_cast<Time*>(self_));
  return new Integer(tm.tm_mday);
}

inline BasicObject* intrinsic_time_month(BasicObject* self_) {
  struct tm tm = time_detail::to_tm(static_cast<Time*>(self_));
  return new Integer(tm.tm_mon + 1);
}

inline BasicObject* intrinsic_time_year(BasicObject* self_) {
  struct tm tm = time_detail::to_tm(static_cast<Time*>(self_));
  return new Integer(tm.tm_year + 1900);
}

inline BasicObject* intrinsic_time_wday(BasicObject* self_) {
  struct tm tm = time_detail::to_tm(static_cast<Time*>(self_));
  return new Integer(tm.tm_wday);
}

inline BasicObject* intrinsic_time_yday(BasicObject* self_) {
  struct tm tm = time_detail::to_tm(static_cast<Time*>(self_));
  return new Integer(tm.tm_yday + 1);
}

inline BasicObject* intrinsic_time_usec(BasicObject* self_) {
  return new Integer(static_cast<Time*>(self_)->nsec_ / 1000);
}

inline BasicObject* intrinsic_time_nsec(BasicObject* self_) {
  return new Integer(static_cast<Time*>(self_)->nsec_);
}

inline BasicObject* intrinsic_time_utc_q(BasicObject* self_) {
  return boxed_bool(static_cast<Time*>(self_)->is_utc_);
}

inline BasicObject* intrinsic_time_utc_offset(BasicObject* self_) {
  auto* t = static_cast<Time*>(self_);
  return new Integer(t->is_utc_ ? 0 : t->utc_offset_);
}

inline BasicObject* intrinsic_time_utc(BasicObject* self_) {
  auto* t = static_cast<Time*>(self_);
  Time* out = new Time();
  out->sec_ = t->sec_;
  out->nsec_ = t->nsec_;
  out->utc_offset_ = 0;
  out->is_utc_ = true;
  return out;
}

inline BasicObject* intrinsic_time_dup(BasicObject* self_) {
  auto* t = static_cast<Time*>(self_);
  Time* out = new Time();
  out->sec_ = t->sec_;
  out->nsec_ = t->nsec_;
  out->utc_offset_ = t->utc_offset_;
  out->is_utc_ = t->is_utc_;
  out->iv_frozone_timezone = t->iv_frozone_timezone;
  return out;
}

inline BasicObject* intrinsic_time_asctime(BasicObject* self_) {
  struct tm tm = time_detail::to_tm(static_cast<Time*>(self_));
  // Format: "Mon Jan 15 12:34:56 2024" (no \n unlike libc ctime).
  std::string s = time_detail::strftime_local("%a %b %e %H:%M:%S %Y", &tm);
  return new String(s.data(), s.size());
}

inline BasicObject* intrinsic_time_strftime(BasicObject* self_, BasicObject* fmt) {
  auto* t = static_cast<Time*>(self_);
  struct tm tm = time_detail::to_tm(t);
  std::string format(reinterpret_cast<const char*>(static_cast<String*>(fmt)->bytes.data()),
                     static_cast<String*>(fmt)->bytes.size());
  std::string s = time_detail::strftime_local(format.c_str(), &tm);
  return new String(s.data(), s.size());
}

inline BasicObject* intrinsic_time_dst_q(BasicObject* /*self_*/) {
  // We don't track DST separately — Time.now uses tm_isdst at construction
  // but doesn't store it. Future work; return false for now.
  return false_instance();
}

inline BasicObject* intrinsic_time_subsec(BasicObject* self_) {
  // Return Integer when nsec is 0, else Float (Rational would be more
  // precise but Rational construction isn't wired up here yet).
  auto* t = static_cast<Time*>(self_);
  if (t->nsec_ == 0) return new Integer(0);
  return new Float(static_cast<double>(t->nsec_) / 1e9);
}

// Time + numeric: add seconds (and fractional ns).
inline BasicObject* intrinsic_time_plus(BasicObject* self_, BasicObject* delta) {
  auto* t = static_cast<Time*>(self_);
  Time* out = new Time();
  out->utc_offset_ = t->utc_offset_;
  out->is_utc_ = t->is_utc_;
  if (&typeid(*delta) == &typeid(Integer)) {
    auto* i = static_cast<Integer*>(delta);
    out->sec_ = t->sec_ + i->raw_;
    out->nsec_ = t->nsec_;
  } else if (&typeid(*delta) == &typeid(Float)) {
    auto* f = static_cast<Float*>(delta);
    double total = static_cast<double>(t->sec_) + static_cast<double>(t->nsec_) / 1e9 + f->raw_;
    out->sec_ = static_cast<int64_t>(total);
    out->nsec_ = static_cast<int32_t>((total - static_cast<double>(out->sec_)) * 1e9);
    if (out->nsec_ < 0) { out->nsec_ += 1'000'000'000; out->sec_ -= 1; }
  } else {
    std::fprintf(stderr, "[box-first] time_plus: unsupported delta type\n");
    std::abort();
  }
  return out;
}

inline BasicObject* intrinsic_time_minus(BasicObject* self_, BasicObject* delta) {
  auto* t = static_cast<Time*>(self_);
  // Time - Time → Float seconds; Time - Numeric → Time.
  if (&typeid(*delta) == &typeid(Time)) {
    auto* other = static_cast<Time*>(delta);
    double d = (static_cast<double>(t->sec_) - static_cast<double>(other->sec_))
             + (static_cast<double>(t->nsec_) - static_cast<double>(other->nsec_)) / 1e9;
    return new Float(d);
  }
  // Delegate to time_plus with negated delta.
  if (&typeid(*delta) == &typeid(Integer)) {
    auto* i = static_cast<Integer*>(delta);
    Integer* neg = new Integer(-i->raw_);
    return intrinsic_time_plus(self_, neg);
  }
  if (&typeid(*delta) == &typeid(Float)) {
    auto* f = static_cast<Float*>(delta);
    Float* neg = new Float(-f->raw_);
    return intrinsic_time_plus(self_, neg);
  }
  std::fprintf(stderr, "[box-first] time_minus: unsupported delta type\n");
  std::abort();
}

inline BasicObject* intrinsic_time_round(BasicObject* self_, BasicObject* ndigits) {
  auto* t = static_cast<Time*>(self_);
  int n = 0;
  if (ndigits && ndigits != nil_instance()) {
    if (&typeid(*ndigits) == &typeid(Integer)) n = static_cast<int>(static_cast<Integer*>(ndigits)->raw_);
  }
  if (n >= 9) return intrinsic_time_dup(self_);
  Time* out = new Time();
  out->sec_ = t->sec_;
  out->utc_offset_ = t->utc_offset_;
  out->is_utc_ = t->is_utc_;
  // Keep first n digits of nsec (banker round on next digit).
  int divisor = 1;
  for (int i = 0; i < 9 - n; i++) divisor *= 10;
  int kept = t->nsec_ / divisor;
  int rem  = t->nsec_ % divisor;
  if (rem * 2 >= divisor) kept += 1;
  int rounded = kept * divisor;
  if (rounded >= 1'000'000'000) { rounded -= 1'000'000'000; out->sec_ += 1; }
  out->nsec_ = rounded;
  return out;
}

inline BasicObject* intrinsic_time_floor(BasicObject* self_, BasicObject* ndigits) {
  auto* t = static_cast<Time*>(self_);
  int n = 0;
  if (ndigits && ndigits != nil_instance()) {
    if (&typeid(*ndigits) == &typeid(Integer)) n = static_cast<int>(static_cast<Integer*>(ndigits)->raw_);
  }
  if (n >= 9) return intrinsic_time_dup(self_);
  Time* out = new Time();
  out->sec_ = t->sec_;
  out->utc_offset_ = t->utc_offset_;
  out->is_utc_ = t->is_utc_;
  int divisor = 1;
  for (int i = 0; i < 9 - n; i++) divisor *= 10;
  out->nsec_ = (t->nsec_ / divisor) * divisor;
  return out;
}

inline BasicObject* intrinsic_time_ceil(BasicObject* self_, BasicObject* ndigits) {
  auto* t = static_cast<Time*>(self_);
  int n = 0;
  if (ndigits && ndigits != nil_instance()) {
    if (&typeid(*ndigits) == &typeid(Integer)) n = static_cast<int>(static_cast<Integer*>(ndigits)->raw_);
  }
  if (n >= 9) return intrinsic_time_dup(self_);
  Time* out = new Time();
  out->sec_ = t->sec_;
  out->utc_offset_ = t->utc_offset_;
  out->is_utc_ = t->is_utc_;
  int divisor = 1;
  for (int i = 0; i < 9 - n; i++) divisor *= 10;
  int kept = (t->nsec_ + divisor - 1) / divisor;
  int rounded = kept * divisor;
  if (rounded >= 1'000'000'000) { rounded -= 1'000'000'000; out->sec_ += 1; }
  out->nsec_ = rounded;
  return out;
}

inline BasicObject* intrinsic_time_zone(BasicObject* self_) {
  auto* t = static_cast<Time*>(self_);
  if (t->is_utc_) return new String("UTC", 3);
  // Local zone — query localtime tm_zone.
  time_t s = static_cast<time_t>(t->sec_);
  struct tm tm{};
  ::localtime_r(&s, &tm);
#ifdef __USE_MISC
  const char* z = tm.tm_zone ? tm.tm_zone : "";
  return new String(z, std::strlen(z));
#else
  return new String("", 0);
#endif
}

inline BasicObject* intrinsic_time_localtime(BasicObject* self_, BasicObject* /*offset*/) {
  auto* t = static_cast<Time*>(self_);
  Time* out = new Time();
  out->sec_ = t->sec_;
  out->nsec_ = t->nsec_;
  out->is_utc_ = false;
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
  return out;
}

// Time.at(int_or_float) — minimal form, no Rational. Time-zone offset
// from MRI's `in:` kwarg isn't honoured here; callers wanting an explicit
// tz must use time_localtime or set iv_frozone_timezone after the fact.
inline BasicObject* intrinsic_time_at(BasicObject* secs) {
  Time* out = new Time();
  if (&typeid(*secs) == &typeid(Integer)) {
    auto* i = static_cast<Integer*>(secs);
    out->sec_ = i->raw_;
    out->nsec_ = 0;
  } else if (&typeid(*secs) == &typeid(Float)) {
    auto* f = static_cast<Float*>(secs);
    out->sec_ = static_cast<int64_t>(f->raw_);
    double frac = f->raw_ - static_cast<double>(out->sec_);
    out->nsec_ = static_cast<int32_t>(frac * 1e9);
    if (out->nsec_ < 0) { out->nsec_ += 1'000'000'000; out->sec_ -= 1; }
  } else {
    std::fprintf(stderr, "[box-first] time_at: only Integer/Float supported (Rational TODO)\n");
    std::abort();
  }
  // Default to local time, mirror time_now's offset computation.
  time_t s = static_cast<time_t>(out->sec_);
  struct tm lt{};
  ::localtime_r(&s, &lt);
#ifdef __USE_MISC
  out->utc_offset_ = static_cast<int32_t>(lt.tm_gmtoff);
#else
  struct tm gt{};
  ::gmtime_r(&s, &gt);
  out->utc_offset_ = static_cast<int32_t>(::mktime(&gt) - ::mktime(&lt));
#endif
  return out;
}

// ---- Stubs for not-yet-implemented entry points -----------------
// Rational round-trip required:
inline BasicObject* intrinsic_time_to_r(BasicObject* /*self_*/) {
  std::fprintf(stderr, "[box-first] time_to_r: Rational construction not yet wired up\n");
  std::abort();
}
inline BasicObject* intrinsic_time_at_raw(BasicObject* /*r*/, BasicObject* /*offset*/) {
  std::fprintf(stderr, "[box-first] time_at_raw: needs Rational/timezone object support\n");
  std::abort();
}
// Full struct-tm construction (year/mon/day/h/m/s/usec/utc[/dst]).
// Called from time.rb with both 8 args (no isdst) and 9 (with isdst);
// default-arg the trailing isdst so both forms reach this stub.
inline BasicObject* intrinsic_time_mktime(BasicObject* /*y*/, BasicObject* /*mo*/, BasicObject* /*d*/,
                                          BasicObject* /*h*/, BasicObject* /*mi*/, BasicObject* /*s*/,
                                          BasicObject* /*us*/, BasicObject* /*use_utc*/,
                                          BasicObject* /*isdst*/ = nullptr) {
  std::fprintf(stderr, "[box-first] time_mktime: not yet implemented\n");
  std::abort();
}
// 7-arg Time.new constructor:
inline BasicObject* intrinsic_time_new(BasicObject* /*y*/, BasicObject* /*mo*/, BasicObject* /*d*/,
                                       BasicObject* /*h*/, BasicObject* /*mi*/, BasicObject* /*s*/,
                                       BasicObject* /*tz*/) {
  std::fprintf(stderr, "[box-first] time_new: not yet implemented\n");
  std::abort();
}
// Time.new from ISO8601 string:
inline BasicObject* intrinsic_time_new_from_string(BasicObject* /*str*/, BasicObject* /*prec*/, BasicObject* /*tz*/) {
  std::fprintf(stderr, "[box-first] time_new_from_string: not yet implemented (strptime TODO)\n");
  std::abort();
}
// Marshal:
inline BasicObject* intrinsic_time_dump(BasicObject* /*self_*/) {
  std::fprintf(stderr, "[box-first] time_dump: marshal not yet implemented\n");
  std::abort();
}
inline BasicObject* intrinsic_time_load(BasicObject* /*str*/) {
  std::fprintf(stderr, "[box-first] time_load: marshal not yet implemented\n");
  std::abort();
}
// ISO8601 formatting (could reuse strftime but not wired up here):
inline BasicObject* intrinsic_time_iso8601(BasicObject* /*self_*/, BasicObject* /*frac*/) {
  std::fprintf(stderr, "[box-first] time_iso8601: not yet implemented\n");
  std::abort();
}

#endif  // FROZONE_TIME_INTRINSICS_HPP
