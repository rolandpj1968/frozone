# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Integer
        def integer_hash(_, v) = n2f_int(v.raw.hash)
        def integer_eql(_, v1, v2) = n2f_bool(fint?(v2) && v1.raw == v2.raw)
        def integer_to_s(_, v, base = FNIL) = n2f_str(v.raw.to_s(fnil?(base) ? 10 : base.raw))
        def integer_abs(_, v) = n2f_int(v.raw.abs)
        def integer_bitand(_, v1, v2) = n2f_int(v1.raw & v2.raw)
        def integer_bitor(_, v1, v2) = n2f_int(v1.raw | v2.raw)
        def integer_bitxor(_, v1, v2) = n2f_int(v1.raw ^ v2.raw)
        def integer_bitnot(_, v) = n2f_int(~v.raw)
        def integer_bit(_, v, n) = n2f_int(v.raw[n.raw])
        def integer_bit_length(_, v) = n2f_int(v.raw.bit_length)
        def integer__lt_(_, v1, v2) = n2f_bool(v1.raw <  integer_raw(v2))
        def integer__le_(_, v1, v2) = n2f_bool(v1.raw <= integer_raw(v2))
        def integer__ge_(_, v1, v2) = n2f_bool(v1.raw >= integer_raw(v2))
        def integer__gt_(_, v1, v2) = n2f_bool(v1.raw >  integer_raw(v2))
        def integer__eq_(_, v1, v2) = n2f_bool(v1.raw == (fint?(v2) || ffloat?(v2) ? v2.raw : nil))
        def integer__plus_(_, v1, v2) = numeric_wrap(v1.raw + integer_raw(v2))
        def integer__minus_(_, v1, v2) = numeric_wrap(v1.raw - integer_raw(v2))
        def integer__mul_(_, v1, v2) = numeric_wrap(v1.raw * integer_raw(v2))
        def integer__div_(_, v1, v2) = numeric_wrap(v1.raw / integer_raw(v2))
        def integer__mod_(_, v1, v2) = numeric_wrap(v1.raw % integer_raw(v2))
        def integer__pow_(_, v1, v2) = numeric_wrap(v1.raw**integer_raw(v2))
        def integer_to_f(_, v) = n2f_float(v.raw.to_f)

        def integer_spaceship(_, v1, v2)
          return FNIL unless fint?(v2) || ffloat?(v2)
          result = v1.raw <=> v2.raw
          result.nil? ? FNIL : n2f_int(result)
        end

        def integer_fdiv(context, v, n)
          n_val = fint?(n) ? n.raw : ffloat?(n) ? n.raw : nil
          if n_val
            n2f_float(v.raw.fdiv(n_val))
          elsif fobj?(n)
            has_coerce = n.dispatch(context, :respond_to?, [n2f_sym(:coerce)], {}).truthy? rescue false
            if has_coerce
              pair = n.dispatch(context, :coerce, [v], {})
              a = pair.raw[0]
              b = pair.raw[1]
              a.dispatch(context, :fdiv, [b], {})
            else
              raise FrozoneException.make(:TypeError, "#{n.class_object&.name} can't be coerced into Integer")
            end
          else
            raise FrozoneException.make(:TypeError, "#{n.class} can't be coerced into Integer")
          end
        end

        def integer_chr(context, v, enc = FNIL)
          if fnil?(enc)
            n2f_str(v.raw.chr)
          elsif fstr?(enc)
            n2f_str(v.raw.chr(enc.raw))
          elsif enc.is_a?(ObjectObject)
            # Encoding Frozone-land object — dispatch :name to get string name
            enc_name = begin
              r = enc.dispatch(context, :name, [], {})
              fstr?(r) ? r.raw : enc.get_ivar(:@name)&.raw
            rescue FrozoneException
              enc.get_ivar(:@name)&.raw
            end
            enc_name ||= 'UTF-8'
            reraise(::RangeError) { n2f_str(v.raw.chr(enc_name)) }
          else
            n2f_str(v.raw.chr)
          end
        end

        SHIFT_LIMIT = 2**32

        def integer_lshift(_, v1, v2)
          n = v1.raw
          m = fint?(v2) ? v2.raw : v2.raw.to_i
          if m < 0
            shift = m.abs > 1_000_000 ? 1_000_000 : m.abs
            n2f_int(n >> shift)
          elsif m >= SHIFT_LIMIT && n != 0
            raise FrozoneException.make(:RangeError, 'shift width too big')
          else
            n2f_int(n << m)
          end
        end

        def integer_rshift(_, v1, v2)
          n = v1.raw
          m = fint?(v2) ? v2.raw : v2.raw.to_i
          if m < 0
            raise FrozoneException.make(:RangeError, 'shift width too big') if m.abs >= SHIFT_LIMIT && n != 0
            n2f_int(n << m.abs)
          elsif m > 1_000_000
            n2f_int(n >= 0 ? 0 : -1)
          else
            n2f_int(n >> m)
          end
        end

        def integer_raw(v)
          return v.raw if fint?(v) || ffloat?(v)
          raise FrozoneException.make(:TypeError, "#{v.is_a?(ObjectObject) ? (v.class_object&.name || 'Object') : v.class} can't be coerced into Integer")
        end

        def numeric_wrap(result)
          case result
          when ::Float    then n2f_float(result)
          when ::Integer  then n2f_int(result)
          when ::Rational then Core::OBJECT_CLASS.get_constant(:Rational) ? make_rational(result) : n2f_float(result.to_f)
          else n2f_int(result.to_i)
          end
        end

        def make_rational(r)
          rat_class = Core::OBJECT_CLASS.get_constant(:Rational)
          obj = ObjectObject.new(rat_class)
          obj.set_ivar(:@numerator, n2f_int(r.numerator))
          obj.set_ivar(:@denominator, n2f_int(r.denominator))
          obj
        end

        def integer_to_r(context, v)
          r_class = Core::OBJECT_CLASS.get_constant(:Rational)
          return n2f_str("#{v.raw}/1") unless r_class
          make_rational(v.raw.to_r)
        end

        def integer_to_c(context, v)
          c_class = Core::OBJECT_CLASS.get_constant(:Complex)
          return n2f_str("#{v.raw}+0i") unless c_class
          c_class.dispatch(context, :new, [v, n2f_int(0)], {})
        end

        # Float intrinsics
        def float_eql(_, v1, v2) = n2f_bool(ffloat?(v2) && v1.raw == v2.raw)
        def float_hash(_, v) = n2f_int(v.raw.hash)
        def float_to_s(_, v) = n2f_str(v.raw.inspect)
        def float_to_i(_, v) = n2f_int(v.raw.to_i)
        def float_to_r(_, v) = make_rational(v.raw.to_r)
        def float_abs(_, v) = n2f_float(v.raw.abs)
        def float_nan?(_, v) = n2f_bool(v.raw.nan?)
        def float_finite?(_, v) = n2f_bool(v.raw.finite?)
        def float_zero?(_, v) = n2f_bool(v.raw.zero?)
        def float_positive?(_, v) = n2f_bool(v.raw.positive?)
        def float_negative?(_, v) = n2f_bool(v.raw.negative?)
        def float_remainder(_, v1, v2) = n2f_float(v1.raw.remainder(v2.raw))
        def float__lt_(_, v1, v2) = ffloat?(v2) || fint?(v2) ? n2f_bool(v1.raw <  v2.raw) : FFALSE
        def float__le_(_, v1, v2) = ffloat?(v2) || fint?(v2) ? n2f_bool(v1.raw <= v2.raw) : FFALSE
        def float__ge_(_, v1, v2) = ffloat?(v2) || fint?(v2) ? n2f_bool(v1.raw >= v2.raw) : FFALSE
        def float__gt_(_, v1, v2) = ffloat?(v2) || fint?(v2) ? n2f_bool(v1.raw >  v2.raw) : FFALSE
        def float__plus_(_, v1, v2) = n2f_float(v1.raw + v2.raw)
        def float__minus_(_, v1, v2) = n2f_float(v1.raw - v2.raw)
        def float__mul_(_, v1, v2) = n2f_float(v1.raw * v2.raw)
        def float__div_(_, v1, v2) = n2f_float(v1.raw / v2.raw)
        def float__mod_(_, v1, v2) = n2f_float(v1.raw % v2.raw)
        def float__pow_(_, v1, v2) = n2f_float(v1.raw**v2.raw)
        def float_infinity(_) = n2f_float(::Float::INFINITY)
        def float_nan(_) = n2f_float(::Float::NAN)
        def float_next_float(_, v) = n2f_float(v.raw.next_float)
        def float_prev_float(_, v) = n2f_float(v.raw.prev_float)
        def float_infinite?(_, v) = (r = v.raw.infinite?; r ? n2f_int(r) : FNIL)
        def float_divmod(_, v1, v2) = (q, r = v1.raw.divmod(v2.raw); n2f_arr([n2f_int(q), n2f_float(r)]))

        def float_eq(_, v1, v2)
          return n2f_bool(false) unless ffloat?(v2) || fint?(v2)
          n2f_bool(v1.raw == v2.raw)
        end

        def float_spaceship(_, v1, v2)
          return FNIL unless ffloat?(v2) || fint?(v2)
          r = v1.raw <=> v2.raw
          r ? n2f_int(r) : FNIL
        end

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
      end
    end
  end
end
