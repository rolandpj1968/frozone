// Float-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.
//
// The simple Float ops (arithmetic, comparison, scalar <cmath>) lower
// inline via IntrinsicLowering::TEMPLATES. The functions here are the
// ones with real branching: the round family (optional ndigits decides
// Integer-vs-Float return; `half:` mode for round) and the multi-value
// returns (frexp / lgamma).

#ifndef FROZONE_FLOAT_INTRINSICS_HPP
#define FROZONE_FLOAT_INTRINSICS_HPP


#include "../intrinsics_helpers.hpp"

namespace Ruby {

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

BasicObject* intrinsic_float_ceil(BasicObject* self_, BasicObject* nd);
BasicObject* intrinsic_float_floor(BasicObject* self_, BasicObject* nd);
BasicObject* intrinsic_float_truncate(BasicObject* self_, BasicObject* nd);

// Ruby Float#round(ndigits, half:). `half` is nil (== :up), :even
// (banker's), :up (away from zero), or :down (ties toward zero).
BasicObject* intrinsic_float_round(BasicObject* self_, BasicObject* nd, BasicObject* half);

// Math.frexp(x) → [mantissa, exponent].
BasicObject* intrinsic_float_frexp(BasicObject* self_);

// Math.lgamma(x) → [log|gamma(x)|, sign]. lgamma_r supplies the sign.
BasicObject* intrinsic_float_lgamma(BasicObject* self_);

// Math.gamma(x) — true gamma function. tgamma() handles negatives,
// poles at non-positive integers, and overflow per IEEE 754 (returns
// Infinity for poles / overflow; NaN for invalid inputs).
BasicObject* intrinsic_float_gamma(BasicObject* self_);


}  // namespace Ruby

#endif
