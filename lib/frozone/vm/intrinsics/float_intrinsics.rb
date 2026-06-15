# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Float
        def float_hash(_, v) = n2f_int(v.raw.hash)
        def float_to_s(_, v) = n2f_str(v.raw.inspect)
        def float_to_r(_, v) = make_rational(v.raw.to_r)
        def float__lt_(_, v1, v2) = n2f_bool(v1.raw <  v2.raw)
        def float__le_(_, v1, v2) = n2f_bool(v1.raw <= v2.raw)
        def float__ge_(_, v1, v2) = n2f_bool(v1.raw >= v2.raw)
        def float__gt_(_, v1, v2) = n2f_bool(v1.raw >  v2.raw)
        def float__plus_(_, v1, v2) = n2f_float(v1.raw + v2.raw)
        def float__minus_(_, v1, v2) = n2f_float(v1.raw - v2.raw)
        def float__mul_(_, v1, v2) = n2f_float(v1.raw * v2.raw)
        def float__div_(_, v1, v2) = n2f_float(v1.raw / v2.raw)
        def float__mod_(_, v1, v2) = n2f_float(v1.raw % v2.raw)
        def float__pow_(_, v1, v2) = n2f_float(v1.raw**v2.raw)
        def float_infinity(_) = n2f_float(::Float::INFINITY)
        def float_nan(_) = n2f_float(::Float::NAN)
        def float_divmod(_, v1, v2) = (q, r = v1.raw.divmod(v2.raw); n2f_arr([n2f_int(q), n2f_float(r)]))
        def float_remainder(_, v1, v2) = n2f_float(v1.raw.remainder(v2.raw))
        def float_next_float(_, v) = n2f_float(v.raw.next_float)
        def float_prev_float(_, v) = n2f_float(v.raw.prev_float)

        def float_eq(_, v1, v2) = n2f_bool(v1.raw == v2.raw)
        def float_spaceship(_, v1, v2) = (r = v1.raw <=> v2.raw) ? n2f_int(r) : FNIL

        def float_ceil(_, v, n = FNIL)
          n_raw = f2n_raw(n)
          result = n_raw.nil? ? v.raw.ceil : v.raw.ceil(n_raw)
          result.is_a?(::Integer) ? n2f_int(result) : n2f_float(result)
        end

        def float_floor(_, v, n = FNIL)
          n_raw = f2n_raw(n)
          result = n_raw.nil? ? v.raw.floor : v.raw.floor(n_raw)
          result.is_a?(::Integer) ? n2f_int(result) : n2f_float(result)
        end

        def float_round(_, v, n = FNIL, half = FNIL)
          n_raw = f2n_raw(n)
          half_raw = fnil?(half) ? nil : (fsym?(half) ? half.raw : half.raw.to_sym)
          opts = half_raw ? { half: half_raw } : {}
          result = n_raw.nil? ? v.raw.round(**opts) : v.raw.round(n_raw, **opts)
          result.is_a?(::Integer) ? n2f_int(result) : n2f_float(result)
        end

        def float_truncate(_, v, n = FNIL)
          n_raw = f2n_raw(n)
          result = n_raw.nil? ? v.raw.truncate : v.raw.truncate(n_raw)
          result.is_a?(::Integer) ? n2f_int(result) : n2f_float(result)
        end

        def float_rationalize(context, v, eps = FNIL)
          if fnil?(eps)
            make_rational(v.raw.rationalize)
          elsif ffloat?(eps) || fint?(eps)
            eps_raw = eps.raw < 0 ? -eps.raw : eps.raw
            make_rational(v.raw.rationalize(eps_raw))
          else
            num = eps.get_ivar(:@numerator)
            den = eps.get_ivar(:@denominator)
            eps_r = Rational(num.raw, den.raw)
            eps_r = -eps_r if eps_r < 0
            make_rational(v.raw.rationalize(eps_r))
          end
        end

        # Math module functions
        def float_sqrt(_, v) = n2f_float(::Math.sqrt(v.raw))
        def float_cbrt(_, v) = n2f_float(::Math.cbrt(v.raw))
        def float_exp(_, v) = n2f_float(::Math.exp(v.raw))
        def float_log(_, v) = n2f_float(::Math.log(v.raw))
        def float_log2(_, v) = n2f_float(::Math.log2(v.raw))
        def float_log10(_, v) = n2f_float(::Math.log10(v.raw))
        def float_sin(_, v) = n2f_float(::Math.sin(v.raw))
        def float_cos(_, v) = n2f_float(::Math.cos(v.raw))
        def float_tan(_, v) = n2f_float(::Math.tan(v.raw))
        def float_asin(_, v) = n2f_float(::Math.asin(v.raw))
        def float_acos(_, v) = n2f_float(::Math.acos(v.raw))
        def float_atan(_, v) = n2f_float(::Math.atan(v.raw))
        def float_atan2(_, y, x) = n2f_float(::Math.atan2(y.raw, x.raw))
        def float_sinh(_, v) = n2f_float(::Math.sinh(v.raw))
        def float_cosh(_, v) = n2f_float(::Math.cosh(v.raw))
        def float_tanh(_, v) = n2f_float(::Math.tanh(v.raw))
        def float_asinh(_, v) = n2f_float(::Math.asinh(v.raw))
        def float_acosh(_, v) = n2f_float(::Math.acosh(v.raw))
        def float_atanh(_, v) = n2f_float(::Math.atanh(v.raw))
        def float_hypot(_, a, b) = n2f_float(::Math.hypot(a.raw, b.raw))
        def float_ldexp(_, v, n) = n2f_float(::Math.ldexp(v.raw, n.raw))
        def float_erf(_, v) = n2f_float(::Math.erf(v.raw))
        def float_erfc(_, v) = n2f_float(::Math.erfc(v.raw))
        def float_expm1(_, v) = n2f_float(::Math.expm1(v.raw))
        def float_log1p(_, v) = n2f_float(::Math.log1p(v.raw))
        def float_frexp(_, v) = (m, e = ::Math.frexp(v.raw); n2f_arr([n2f_float(m), n2f_int(e)]))
        def float_lgamma(_, v) = (result, sign = ::Math.lgamma(v.raw); n2f_arr([n2f_float(result), n2f_int(sign)]))

        def float_gamma(_, v)
          begin
            n2f_float(::Math.gamma(v.raw))
          rescue ::Math::DomainError => e
            raise FrozoneException.new(FrozoneException.wrap_mri(e), e.message)
          end
        end

        # IEEE 754 round-trip — leverage MRI's pack/unpack for the
        # bridge so interpreted-mode behaviour matches the box-first
        # C++ intrinsic to the bit.
        def float_to_ieee_be(_, v, width)
          fmt = width.raw == 8 ? 'G' : 'g'
          n2f_str([v.raw].pack(fmt).force_encoding(::Encoding::BINARY))
        end

        def float_from_ieee_be(_, s, width)
          fmt = width.raw == 8 ? 'G' : 'g'
          n2f_float(s.raw.unpack1(fmt))
        end
      end
    end
  end
end
