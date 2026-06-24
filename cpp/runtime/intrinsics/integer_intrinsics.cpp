// Integer-category intrinsic definitions. Declarations live in
// integer_intrinsics.hpp; this TU compiles once per program and the
// linker resolves calls. With LTO, hot bodies inline back into callers.
//
// Not directly compilable: references program types (Integer*, String*,
// ...) declared in frozone_all.hpp. The Rakefile compiles this .cpp
// with `-I cpp/gen/box/<base>/` and routes the .o into the per-program
// gen dir.

#include "frozone_all.hpp"

#include "integer_intrinsics.hpp"
#include "../intrinsics_helpers.hpp"

namespace Ruby {

namespace integer_detail {
  // Ruby `/` rounds toward negative infinity; C++ truncates toward
  // zero. Adjust quotient when signs differ and there's a remainder.
  inline int64_t ruby_div(int64_t a, int64_t b) {
    int64_t q = a / b;
    if ((a % b != 0) && ((a < 0) != (b < 0))) q -= 1;
    return q;
  }
  // Ruby `%` returns a result with the divisor's sign. C++'s `%`
  // returns a result with the dividend's sign. Adjust by adding
  // divisor when signs differ.
  inline int64_t ruby_mod(int64_t a, int64_t b) {
    int64_t r = a % b;
    if (r != 0 && ((r < 0) != (b < 0))) r += b;
    return r;
  }
}

// ---- Integer -------------------------------------------------------

// `Integer#bit_length` — bits needed to represent value (excl. sign).
// Negative numbers: bits in ~n. __builtin_clzll gives leading zeros;
// bit_length = 64 - clz.
BasicObject* intrinsic_integer_bit_length(BasicObject* self_) {
  std::int64_t _v = static_cast<Integer*>(self_)->raw_;
  std::uint64_t _u = (_v < 0) ? static_cast<std::uint64_t>(~_v) : static_cast<std::uint64_t>(_v);
  if (_u == 0) return boxed_int(0);
  return boxed_int(64 - __builtin_clzll(_u));
}

// static_cast<Integer*>: integer.rb dispatches `Intrinsics.integer_X(self, n)`
// only when `n.is_a?(Integer)` is already true (see e.g. `def +(v) = v.is_a?(Integer) ? Intrinsics.integer__plus_(...)` patterns).
// So both args are guaranteed Integer at the intrinsic boundary.
BasicObject* intrinsic_integer_bitand(BasicObject* s, BasicObject* o) {
  return boxed_int(static_cast<Integer*>(s)->raw_ & static_cast<Integer*>(o)->raw_);
}

BasicObject* intrinsic_integer_bitor(BasicObject* s, BasicObject* o) {
  return boxed_int(static_cast<Integer*>(s)->raw_ | static_cast<Integer*>(o)->raw_);
}

BasicObject* intrinsic_integer_bitxor(BasicObject* s, BasicObject* o) {
  return boxed_int(static_cast<Integer*>(s)->raw_ ^ static_cast<Integer*>(o)->raw_);
}

// Integer#/ and #% guard for v == 0 in core/4.0/integer.rb before
// dispatching here, so the divisor is known non-zero at this point.
BasicObject* intrinsic_integer__div_(BasicObject* s, BasicObject* o) {
  return boxed_int(integer_detail::ruby_div(static_cast<Integer*>(s)->raw_, static_cast<Integer*>(o)->raw_));
}

BasicObject* intrinsic_integer__mod_(BasicObject* s, BasicObject* o) {
  return boxed_int(integer_detail::ruby_mod(static_cast<Integer*>(s)->raw_, static_cast<Integer*>(o)->raw_));
}

BasicObject* intrinsic_integer_fdiv(BasicObject* s, BasicObject* o) {
  // o may be Integer or Float - integer.rb's `def fdiv(n) = Intrinsics.integer_fdiv(self, n)`
  // is the only caller and accepts both. Branch on actual class.
  double a = static_cast<double>(static_cast<Integer*>(s)->raw_);
  if (o->m_class(univ) == reinterpret_cast<BasicObject*>(&Float_CLASS)) {
    return new Float(a / static_cast<Float*>(o)->raw_);
  }
  return new Float(a / static_cast<double>(static_cast<Integer*>(o)->raw_));
}

// Shifts: Ruby promotes to Bignum on overflow. Box-first stays Int64.
// For shifts that exceed 63 bits, the C++ behaviour is UB. We mask the
// shift amount to [0, 63] and accept loss of precision as a known
// soundness gap (tracked in project_int_soundness.md). Negative shift
// is the opposite-direction operator (Ruby semantics: `1 << -1` == `1 >> 1`).
BasicObject* intrinsic_integer_lshift(BasicObject* s, BasicObject* n) {
  int64_t a = static_cast<Integer*>(s)->raw_;
  int64_t k = static_cast<Integer*>(n)->raw_;
  if (k >= 64) return boxed_int(0);
  if (k <= -64) return boxed_int(a < 0 ? -1 : 0);
  if (k < 0) return boxed_int(a >> (-k));
  return boxed_int(static_cast<int64_t>(static_cast<uint64_t>(a) << k));
}

BasicObject* intrinsic_integer_rshift(BasicObject* s, BasicObject* n) {
  int64_t a = static_cast<Integer*>(s)->raw_;
  int64_t k = static_cast<Integer*>(n)->raw_;
  if (k >= 64) return boxed_int(a < 0 ? -1 : 0);
  if (k <= -64) return boxed_int(0);
  if (k < 0) return boxed_int(static_cast<int64_t>(static_cast<uint64_t>(a) << (-k)));
  return boxed_int(a >> k);
}

BasicObject* intrinsic_integer__pow_(BasicObject* s, BasicObject* v) {
  // integer.rb's `**` already handles negative exponents and Float
  // exponents — by the time we're here, v is a non-negative Integer.
  int64_t base = static_cast<Integer*>(s)->raw_;
  int64_t exp = static_cast<Integer*>(v)->raw_;
  if (exp < 0) {
    // Defensive: should be unreachable per the Ruby wrapper.
    std::fprintf(stderr, "[box-first] integer__pow_: negative exponent reached intrinsic\n");
    std::abort();
  }
  // Iterative exponentiation by squaring. Overflow on the multiply is
  // UB today (bignum promotion would catch it); abort on detected
  // overflow rather than silently wrapping.
  int64_t result = 1;
  while (exp > 0) {
    if (exp & 1) {
      int64_t prod;
      if (__builtin_mul_overflow(result, base, &prod)) {
        std::fprintf(stderr, "[box-first] integer__pow_: overflow (Bignum promotion not yet supported)\n");
        std::abort();
      }
      result = prod;
    }
    exp >>= 1;
    if (exp > 0) {
      int64_t sq;
      if (__builtin_mul_overflow(base, base, &sq)) {
        std::fprintf(stderr, "[box-first] integer__pow_: overflow during squaring (Bignum promotion not yet supported)\n");
        std::abort();
      }
      base = sq;
    }
  }
  return boxed_int(result);
}

BasicObject* intrinsic_integer_to_f(BasicObject* s) {
  return new Float(static_cast<double>(static_cast<Integer*>(s)->raw_));
}

BasicObject* intrinsic_integer_to_s(BasicObject* s, BasicObject* base) {
  int64_t v = static_cast<Integer*>(s)->raw_;
  int b = (base == nil_instance()) ? 10 : static_cast<int>(static_cast<Integer*>(base)->raw_);
  if (b < 2 || b > 36) {
    std::fprintf(stderr, "[box-first] integer_to_s: invalid radix %d\n", b);
    std::abort();
  }
  // Base 10 → snprintf is fast and handles INT64_MIN correctly.
  if (b == 10) {
    char buf[32];
    int n = std::snprintf(buf, sizeof(buf), "%lld", static_cast<long long>(v));
    return new String(buf, n);
  }
  // Other bases: build digits in reverse, then flip. Handle the
  // INT64_MIN edge case (negation overflows) by working in unsigned.
  bool neg = v < 0;
  uint64_t u = neg ? (static_cast<uint64_t>(-(v + 1)) + 1) : static_cast<uint64_t>(v);
  char buf[66];
  int i = 0;
  if (u == 0) buf[i++] = '0';
  while (u != 0) {
    int d = static_cast<int>(u % static_cast<uint64_t>(b));
    buf[i++] = (d < 10) ? ('0' + d) : ('a' + d - 10);
    u /= static_cast<uint64_t>(b);
  }
  if (neg) buf[i++] = '-';
  // Reverse in place.
  for (int j = 0, k = i - 1; j < k; ++j, --k) std::swap(buf[j], buf[k]);
  return new String(buf, i);
}

BasicObject* intrinsic_integer_to_c(BasicObject* /*s*/) {
  // Complex requires the Complex class machinery; box-first stubs out
  // the constructor delegation until a real caller arrives. Throws
  // NotImplementedError so user code can rescue it (was std::abort).
  throw_not_implemented("Integer#to_c not yet supported in box-first (Complex class not wired up)");
}

}  // namespace Ruby
