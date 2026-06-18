// Float-category intrinsic definitions. Declarations live in
// float_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "float_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

BasicObject* intrinsic_float_ceil(BasicObject* self_, BasicObject* nd) {
  return __float_round_to__(self_, nd, [](double x) { return std::ceil(x); });
}

BasicObject* intrinsic_float_floor(BasicObject* self_, BasicObject* nd) {
  return __float_round_to__(self_, nd, [](double x) { return std::floor(x); });
}

BasicObject* intrinsic_float_truncate(BasicObject* self_, BasicObject* nd) {
  return __float_round_to__(self_, nd, [](double x) { return std::trunc(x); });
}

// Ruby Float#round(ndigits, half:). `half` is nil (== :up), :even
// (banker's), :up (away from zero), or :down (ties toward zero).
BasicObject* intrinsic_float_round(BasicObject* self_, BasicObject* nd, BasicObject* half) {
  double v = static_cast<Float*>(self_)->raw_;
  bool ret_int = (nd == nil_instance());
  std::int64_t d = ret_int ? 0 : static_cast<Integer*>(nd)->raw_;
  ret_int = ret_int || (d <= 0);
  double sc = std::pow(10.0, static_cast<double>(d));
  double x = v * sc;
  double r;
  if (half == intern("even")) {
    double fl = std::floor(x);
    double diff = x - fl;
    if (diff < 0.5) r = fl;
    else if (diff > 0.5) r = fl + 1.0;
    else r = (std::fmod(fl, 2.0) == 0.0) ? fl : fl + 1.0;
  } else if (half == intern("down")) {
    double a = std::fabs(x);
    double fa = std::floor(a);
    double ra = ((a - fa) <= 0.5) ? fa : fa + 1.0;
    r = std::copysign(ra, x);
  } else {
    // nil / :up — round half away from zero (Ruby's default).
    r = std::round(x);
  }
  double res = r / sc;
  return ret_int ? static_cast<BasicObject*>(boxed_int(static_cast<std::int64_t>(res)))
                 : static_cast<BasicObject*>(new Float(res));
}

// Math.frexp(x) → [mantissa, exponent].
BasicObject* intrinsic_float_frexp(BasicObject* self_) {
  int e;
  double m = std::frexp(static_cast<Float*>(self_)->raw_, &e);
  return new Array({ static_cast<BasicObject*>(new Float(m)),
                     static_cast<BasicObject*>(boxed_int(static_cast<std::int64_t>(e))) });
}

// Math.lgamma(x) → [log|gamma(x)|, sign]. lgamma_r supplies the sign.
BasicObject* intrinsic_float_lgamma(BasicObject* self_) {
  int sgn;
  double r = lgamma_r(static_cast<Float*>(self_)->raw_, &sgn);
  return new Array({ static_cast<BasicObject*>(new Float(r)),
                     static_cast<BasicObject*>(boxed_int(static_cast<std::int64_t>(sgn))) });
}

BasicObject* intrinsic_float_gamma(BasicObject* self_) {
  return new Float(std::tgamma(static_cast<Float*>(self_)->raw_));
}

BasicObject* intrinsic_float_to_ieee_be(BasicObject* self_, BasicObject* width_) {
  double d = static_cast<Float*>(self_)->raw_;
  std::int64_t w = static_cast<Integer*>(width_)->raw_;
  auto* r = new String();
  r->enc = String::BINARY;
  if (w == 8) {
    std::uint64_t bits;
    std::memcpy(&bits, &d, 8);
    r->bytes.resize(8);
    for (int i = 0; i < 8; i++) r->bytes[i] = static_cast<std::uint8_t>((bits >> ((7 - i) * 8)) & 0xFF);
  } else if (w == 4) {
    float f = static_cast<float>(d);
    std::uint32_t bits;
    std::memcpy(&bits, &f, 4);
    r->bytes.resize(4);
    for (int i = 0; i < 4; i++) r->bytes[i] = static_cast<std::uint8_t>((bits >> ((3 - i) * 8)) & 0xFF);
  } else {
    throw_type_error("float_to_ieee_be: width must be 4 or 8");
  }
  return r;
}

BasicObject* intrinsic_float_from_ieee_be(BasicObject* str_, BasicObject* width_) {
  auto* s = static_cast<String*>(str_);
  std::int64_t w = static_cast<Integer*>(width_)->raw_;
  if (static_cast<std::int64_t>(s->bytes.size()) < w) {
    throw_index_error("float_from_ieee_be: not enough bytes");
  }
  if (w == 8) {
    std::uint64_t bits = 0;
    for (int i = 0; i < 8; i++) bits = (bits << 8) | s->bytes[i];
    double d;
    std::memcpy(&d, &bits, 8);
    return new Float(d);
  } else if (w == 4) {
    std::uint32_t bits = 0;
    for (int i = 0; i < 4; i++) bits = (bits << 8) | s->bytes[i];
    float f;
    std::memcpy(&f, &bits, 4);
    return new Float(static_cast<double>(f));
  }
  throw_type_error("float_from_ieee_be: width must be 4 or 8");
  return nil_instance();
}


}  // namespace Ruby
