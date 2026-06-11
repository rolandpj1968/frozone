// Integer-category intrinsics — split from cpp/runtime/intrinsics.hpp.
// Self-wraps `namespace Ruby { ... }` — `#include` me at TU file
// scope, not inside another `namespace Ruby` block.

#ifndef FROZONE_INTEGER_INTRINSICS_HPP
#define FROZONE_INTEGER_INTRINSICS_HPP



#include "../intrinsics_helpers.hpp"

namespace Ruby {


// ---- Integer -------------------------------------------------------

// `Integer#bit_length` — bits needed to represent value (excl. sign).
// Negative numbers: bits in ~n. __builtin_clzll gives leading zeros;
// bit_length = 64 - clz.
BasicObject* intrinsic_integer_bit_length(BasicObject* self_);

// static_cast<Integer*>: integer.rb dispatches `Intrinsics.integer_X(self, n)`
// only when `n.is_a?(Integer)` is already true (see e.g. `def +(v) = v.is_a?(Integer) ? Intrinsics.integer__plus_(...)` patterns).
// So both args are guaranteed Integer at the intrinsic boundary.
BasicObject* intrinsic_integer_bitand(BasicObject* s, BasicObject* o);
BasicObject* intrinsic_integer_bitor(BasicObject* s, BasicObject* o);
BasicObject* intrinsic_integer_bitxor(BasicObject* s, BasicObject* o);

BasicObject* intrinsic_integer__div_(BasicObject* s, BasicObject* o);

BasicObject* intrinsic_integer__mod_(BasicObject* s, BasicObject* o);

BasicObject* intrinsic_integer_fdiv(BasicObject* s, BasicObject* o);

// Shifts: Ruby promotes to Bignum on overflow. Box-first stays Int64.
// For shifts that exceed 63 bits, the C++ behaviour is UB. We mask the
// shift amount to [0, 63] and accept loss of precision as a known
// soundness gap (tracked in project_int_soundness.md). Negative shift
// is the opposite-direction operator (Ruby semantics: `1 << -1` == `1 >> 1`).
BasicObject* intrinsic_integer_lshift(BasicObject* s, BasicObject* n);
BasicObject* intrinsic_integer_rshift(BasicObject* s, BasicObject* n);

BasicObject* intrinsic_integer__pow_(BasicObject* s, BasicObject* v);

BasicObject* intrinsic_integer_to_f(BasicObject* s);

BasicObject* intrinsic_integer_to_s(BasicObject* s, BasicObject* base);

BasicObject* intrinsic_integer_to_c(BasicObject* /*s*/);
BasicObject* intrinsic_integer_to_r(BasicObject* /*s*/);

}  // namespace Ruby

#endif  // FROZONE_INTEGER_INTRINSICS_HPP
