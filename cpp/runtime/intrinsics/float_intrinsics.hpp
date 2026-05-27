// Float-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Included inside `namespace Ruby { ... }` — do NOT add a namespace wrapper.
//
// The simple Float ops (arithmetic, comparison, scalar <cmath>) lower
// inline via IntrinsicLowering::TEMPLATES. The functions here are the
// ones with real branching: the round family (optional ndigits decides
// Integer-vs-Float return; `half:` mode for round) and the multi-value
// returns (frexp / lgamma).

#ifndef FROZONE_FLOAT_INTRINSICS_HPP
#define FROZONE_FLOAT_INTRINSICS_HPP

// Ruby Float#ceil/floor/truncate(ndigits): ndigits nil or <= 0 returns an
// Integer; ndigits > 0 returns a Float. The op is applied at 10^ndigits
// granularity. (Overflow past int64 is the pre-existing box-first integer
// soundness gap — Bignum promotion is a separate follow-up.)
template <typename Op>
inline BasicObject* __float_round_to__(BasicObject* self_, BasicObject* nd, Op op) {
  double v = static_cast<Float*>(self_)->raw_;
  bool ret_int = (nd == nil_instance());
  std::int64_t d = ret_int ? 0 : static_cast<Integer*>(nd)->raw_;
  ret_int = ret_int || (d <= 0);
  double sc = std::pow(10.0, static_cast<double>(d));
  double r = op(v * sc) / sc;
  return ret_int ? static_cast<BasicObject*>(new Integer(static_cast<std::int64_t>(r)))
                 : static_cast<BasicObject*>(new Float(r));
}

inline BasicObject* intrinsic_float_ceil(BasicObject* self_, BasicObject* nd) {
  return __float_round_to__(self_, nd, [](double x) { return std::ceil(x); });
}
inline BasicObject* intrinsic_float_floor(BasicObject* self_, BasicObject* nd) {
  return __float_round_to__(self_, nd, [](double x) { return std::floor(x); });
}
inline BasicObject* intrinsic_float_truncate(BasicObject* self_, BasicObject* nd) {
  return __float_round_to__(self_, nd, [](double x) { return std::trunc(x); });
}

// Ruby Float#round(ndigits, half:). `half` is nil (== :up), :even
// (banker's), :up (away from zero), or :down (ties toward zero).
inline BasicObject* intrinsic_float_round(BasicObject* self_, BasicObject* nd, BasicObject* half) {
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
  return ret_int ? static_cast<BasicObject*>(new Integer(static_cast<std::int64_t>(res)))
                 : static_cast<BasicObject*>(new Float(res));
}

// Math.frexp(x) → [mantissa, exponent].
inline BasicObject* intrinsic_float_frexp(BasicObject* self_) {
  int e;
  double m = std::frexp(static_cast<Float*>(self_)->raw_, &e);
  return new Array({ static_cast<BasicObject*>(new Float(m)),
                     static_cast<BasicObject*>(new Integer(static_cast<std::int64_t>(e))) });
}

// Math.lgamma(x) → [log|gamma(x)|, sign]. lgamma_r supplies the sign.
inline BasicObject* intrinsic_float_lgamma(BasicObject* self_) {
  int sgn;
  double r = lgamma_r(static_cast<Float*>(self_)->raw_, &sgn);
  return new Array({ static_cast<BasicObject*>(new Float(r)),
                     static_cast<BasicObject*>(new Integer(static_cast<std::int64_t>(sgn))) });
}

#endif
