# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Integer
        def integer_hash(_, v) = n2f_int(v.raw.hash)
        def integer_to_s(_, v, base = FNIL) = n2f_str(v.raw.to_s(fnil?(base) ? 10 : base.raw))
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

        # MRI raises RangeError for shift widths >= 2**67 (ruby-spec: integer/left_shift_spec.rb).
        # Below that, arbitrary-precision bignums handle any shift safely without hanging.
        SHIFT_RANGE_ERROR_LIMIT = 2**67

        def integer_lshift(context, v1, v2)
          n = v1.raw
          m = coerce_to_int(context, v2)
          if m < 0
            # Negative left shift is a right shift; delegate (no RangeError for right shifts of this magnitude).
            n2f_int(n >> m.abs)
          elsif m >= SHIFT_RANGE_ERROR_LIMIT && n != 0
            raise FrozoneException.make(:RangeError, 'shift width too big')
          else
            n2f_int(n << m)
          end
        end

        def integer_rshift(context, v1, v2)
          n = v1.raw
          m = coerce_to_int(context, v2)
          if m < 0
            # Negative right shift is a left shift.
            raise FrozoneException.make(:RangeError, 'shift width too big') if m.abs >= SHIFT_RANGE_ERROR_LIMIT && n != 0
            n2f_int(n << m.abs)
          else
            n2f_int(n >> m)
          end
        end

        # integer_raw: get numeric raw value for integer arithmetic — accepts
        # both Integer and Float arguments (e.g. 5 < 5.5, 5 + 1.0). For objects
        # that implement to_int via dispatch, use coerce_to_int(context, v) instead.
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
      end
    end
  end
end
