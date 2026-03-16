# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Integer
        def integer_spaceship(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(IntegerObject) || v2.is_a?(FloatObject)
          result = v1.raw <=> v2.raw
          result.nil? ? NilObject::NIL : IntegerObject.new(result)
        end

        def integer_hash(_, v) = IntegerObject.new(v.raw.hash)

        def integer_eql(_, v1, v2) = bool_object_for(v2.is_a?(IntegerObject) && v1.raw == v2.raw)

        def integer_to_s(_, v, base = nil)
          base.nil? || base.is_a?(NilObject) ? StringObject.new(v.raw.to_s) : StringObject.new(v.raw.to_s(base.raw))
        end

        def integer_abs(_, v) = IntegerObject.new(v.raw.abs)
        def integer_chr(_, v, enc = nil) = StringObject.new(v.raw.chr)
        def integer_bitand(_, v1, v2) = IntegerObject.new(v1.raw & v2.raw)
        def integer_bitor(_, v1, v2)  = IntegerObject.new(v1.raw | v2.raw)
        def integer_bitxor(_, v1, v2) = IntegerObject.new(v1.raw ^ v2.raw)
        def integer_bitnot(_, v)      = IntegerObject.new(~v.raw)
        SHIFT_LIMIT = 2**32

        def integer_lshift(_, v1, v2)
          n = v1.raw
          m = v2.is_a?(IntegerObject) ? v2.raw : v2.raw.to_i
          if m < 0
            shift = m.abs > 1_000_000 ? 1_000_000 : m.abs
            IntegerObject.new(n >> shift)
          elsif m >= SHIFT_LIMIT && n != 0
            raise FrozoneException.make(:RangeError, 'shift width too big')
          else
            IntegerObject.new(n << m)
          end
        end

        def integer_rshift(_, v1, v2)
          n = v1.raw
          m = v2.is_a?(IntegerObject) ? v2.raw : v2.raw.to_i
          if m < 0
            raise FrozoneException.make(:RangeError, 'shift width too big') if m.abs >= SHIFT_LIMIT && n != 0
            IntegerObject.new(n << m.abs)
          elsif m > 1_000_000
            IntegerObject.new(n >= 0 ? 0 : -1)
          else
            IntegerObject.new(n >> m)
          end
        end
        def integer_bit(_, v, n)      = IntegerObject.new(v.raw[n.raw])
        def integer_bit_length(_, v)  = IntegerObject.new(v.raw.bit_length)

        def integer_raw(v)
          return v.raw if v.is_a?(IntegerObject) || v.is_a?(FloatObject)
          raise FrozoneException.make(:TypeError, "#{v.is_a?(ObjectObject) ? (v.class_object&.name || 'Object') : v.class} can't be coerced into Integer")
        end

        def numeric_wrap(result)
          case result
          when ::Float    then FloatObject.new(result)
          when ::Integer  then IntegerObject.new(result)
          when ::Rational then Core::OBJECT_CLASS.get_constant(:Rational) ? make_rational(result) : FloatObject.new(result.to_f)
          else IntegerObject.new(result.to_i)
          end
        end

        def make_rational(r)
          rat_class = Core::OBJECT_CLASS.get_constant(:Rational)
          obj = ObjectObject.new(rat_class)
          obj.set_ivar(:@numerator, IntegerObject.new(r.numerator))
          obj.set_ivar(:@denominator, IntegerObject.new(r.denominator))
          obj
        end

        def integer__lt_(_, v1, v2)  = bool_object_for(v1.raw <  integer_raw(v2))
        def integer__le_(_, v1, v2)  = bool_object_for(v1.raw <= integer_raw(v2))
        def integer__ge_(_, v1, v2)  = bool_object_for(v1.raw >= integer_raw(v2))
        def integer__gt_(_, v1, v2)  = bool_object_for(v1.raw >  integer_raw(v2))
        def integer__eq_(_, v1, v2)  = bool_object_for(v1.raw == (v2.is_a?(IntegerObject) || v2.is_a?(FloatObject) ? v2.raw : nil))

        def integer__plus_(_, v1, v2)  = numeric_wrap(v1.raw + integer_raw(v2))
        def integer__minus_(_, v1, v2) = numeric_wrap(v1.raw - integer_raw(v2))
        def integer__mul_(_, v1, v2)   = numeric_wrap(v1.raw * integer_raw(v2))
        def integer__div_(_, v1, v2)   = numeric_wrap(v1.raw / integer_raw(v2))
        def integer__mod_(_, v1, v2)   = numeric_wrap(v1.raw % integer_raw(v2))
        def integer__pow_(_, v1, v2)   = numeric_wrap(v1.raw ** integer_raw(v2))

        def integer_to_f(_, v) = FloatObject.new(v.raw.to_f)

        def integer_to_r(context, v)
          r_class = Core::OBJECT_CLASS.get_constant(:Rational)
          return StringObject.new("#{v.raw}/1") unless r_class
          r_class.dispatch(context, :new, [v, IntegerObject.new(1)], {})
        end

        def integer_to_c(context, v)
          c_class = Core::OBJECT_CLASS.get_constant(:Complex)
          return StringObject.new("#{v.raw}+0i") unless c_class
          c_class.dispatch(context, :new, [v, IntegerObject.new(0)], {})
        end

        # Float intrinsics
        def float_eq(_, v1, v2)
          return bool_object_for(false) unless v2.is_a?(FloatObject) || v2.is_a?(IntegerObject)
          bool_object_for(v1.raw == v2.raw)
        end

        def float_eql(_, v1, v2)       = bool_object_for(v2.is_a?(FloatObject) && v1.raw == v2.raw)
        def float_hash(_, v)           = IntegerObject.new(v.raw.hash)

        def float_spaceship(_, v1, v2)
          return NilObject::NIL unless v2.is_a?(FloatObject) || v2.is_a?(IntegerObject)
          r = v1.raw <=> v2.raw
          r ? IntegerObject.new(r) : NilObject::NIL
        end

        def float_to_s(_, v)           = StringObject.new(v.raw.inspect)
        def float_to_i(_, v)           = IntegerObject.new(v.raw.to_i)
        def float_to_f(_, v)           = v
        def float_to_r(_, v)           = make_rational(v.raw.to_r)
        def float_abs(_, v)            = FloatObject.new(v.raw.abs)

        def float_ceil(_, v, n = nil)
          n_raw = n.nil? || n.is_a?(NilObject) ? nil : n.raw
          result = n_raw.nil? ? v.raw.ceil : v.raw.ceil(n_raw)
          result.is_a?(::Integer) ? IntegerObject.new(result) : FloatObject.new(result)
        end

        def float_floor(_, v, n = nil)
          n_raw = n.nil? || n.is_a?(NilObject) ? nil : n.raw
          result = n_raw.nil? ? v.raw.floor : v.raw.floor(n_raw)
          result.is_a?(::Integer) ? IntegerObject.new(result) : FloatObject.new(result)
        end

        def float_round(_, v, n = nil, half = nil)
          n_raw = n.nil? || n.is_a?(NilObject) ? nil : n.raw
          half_raw = half.nil? || half.is_a?(NilObject) ? nil : (half.is_a?(SymbolObject) ? half.raw : half.raw.to_sym)
          opts = half_raw ? { half: half_raw } : {}
          result = n_raw.nil? ? v.raw.round(**opts) : v.raw.round(n_raw, **opts)
          result.is_a?(::Integer) ? IntegerObject.new(result) : FloatObject.new(result)
        end

        def float_truncate(_, v, n = nil)
          n_raw = n.nil? || n.is_a?(NilObject) ? nil : n.raw
          result = n_raw.nil? ? v.raw.truncate : v.raw.truncate(n_raw)
          result.is_a?(::Integer) ? IntegerObject.new(result) : FloatObject.new(result)
        end
        def float_infinity(_)    = FloatObject.new(::Float::INFINITY)
        def float_nan(_)         = FloatObject.new(::Float::NAN)
        def float_next_float(_, v) = FloatObject.new(v.raw.next_float)
        def float_prev_float(_, v) = FloatObject.new(v.raw.prev_float)
        def float_rationalize(context, v, eps = nil)
          if eps.nil? || eps.is_a?(NilObject)
            make_rational(v.raw.rationalize)
          elsif eps.is_a?(FloatObject) || eps.is_a?(IntegerObject)
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
        def float_nan?(_, v)           = bool_object_for(v.raw.nan?)

        def float_infinite?(_, v)
          r = v.raw.infinite?
          r ? IntegerObject.new(r) : NilObject::NIL
        end

        def float_finite?(_, v)        = bool_object_for(v.raw.finite?)
        def float_zero?(_, v)          = bool_object_for(v.raw.zero?)
        def float_positive?(_, v)      = bool_object_for(v.raw.positive?)
        def float_negative?(_, v)      = bool_object_for(v.raw.negative?)

        def float_divmod(_, v1, v2)
          q, r = v1.raw.divmod(v2.raw)
          ArrayObject.new([IntegerObject.new(q), FloatObject.new(r)])
        end

        def float__lt_(_, v1, v2) = v2.is_a?(FloatObject) || v2.is_a?(IntegerObject) ? bool_object_for(v1.raw <  v2.raw) : FalseObject::FALSE
        def float__le_(_, v1, v2) = v2.is_a?(FloatObject) || v2.is_a?(IntegerObject) ? bool_object_for(v1.raw <= v2.raw) : FalseObject::FALSE
        def float__ge_(_, v1, v2) = v2.is_a?(FloatObject) || v2.is_a?(IntegerObject) ? bool_object_for(v1.raw >= v2.raw) : FalseObject::FALSE
        def float__gt_(_, v1, v2) = v2.is_a?(FloatObject) || v2.is_a?(IntegerObject) ? bool_object_for(v1.raw >  v2.raw) : FalseObject::FALSE

        def float__plus_(_, v1, v2)  = FloatObject.new(v1.raw + v2.raw)
        def float__minus_(_, v1, v2) = FloatObject.new(v1.raw - v2.raw)
        def float__mul_(_, v1, v2)   = FloatObject.new(v1.raw * v2.raw)
        def float__div_(_, v1, v2)   = FloatObject.new(v1.raw / v2.raw)
        def float__mod_(_, v1, v2)   = FloatObject.new(v1.raw % v2.raw)
        def float__pow_(_, v1, v2)   = FloatObject.new(v1.raw ** v2.raw)

        # Math module functions
        def float_sqrt(_, v)  = FloatObject.new(::Math.sqrt(v.raw))
        def float_cbrt(_, v)  = FloatObject.new(::Math.cbrt(v.raw))
        def float_exp(_, v)   = FloatObject.new(::Math.exp(v.raw))
        def float_log(_, v)   = FloatObject.new(::Math.log(v.raw))
        def float_log2(_, v)  = FloatObject.new(::Math.log2(v.raw))
        def float_log10(_, v) = FloatObject.new(::Math.log10(v.raw))
        def float_sin(_, v)   = FloatObject.new(::Math.sin(v.raw))
        def float_cos(_, v)   = FloatObject.new(::Math.cos(v.raw))
        def float_tan(_, v)   = FloatObject.new(::Math.tan(v.raw))
        def float_asin(_, v)  = FloatObject.new(::Math.asin(v.raw))
        def float_acos(_, v)  = FloatObject.new(::Math.acos(v.raw))
        def float_atan(_, v)  = FloatObject.new(::Math.atan(v.raw))
        def float_atan2(_, y, x) = FloatObject.new(::Math.atan2(y.raw, x.raw))
        def float_sinh(_, v)  = FloatObject.new(::Math.sinh(v.raw))
        def float_cosh(_, v)  = FloatObject.new(::Math.cosh(v.raw))
        def float_tanh(_, v)  = FloatObject.new(::Math.tanh(v.raw))
        def float_asinh(_, v) = FloatObject.new(::Math.asinh(v.raw))
        def float_acosh(_, v) = FloatObject.new(::Math.acosh(v.raw))
        def float_atanh(_, v) = FloatObject.new(::Math.atanh(v.raw))
        def float_hypot(_, a, b) = FloatObject.new(::Math.hypot(a.raw, b.raw))
        def float_frexp(_, v)
          m, e = ::Math.frexp(v.raw)
          ArrayObject.new([FloatObject.new(m), IntegerObject.new(e)])
        end
        def float_ldexp(_, v, n) = FloatObject.new(::Math.ldexp(v.raw, n.raw))
      end
    end
  end
end
