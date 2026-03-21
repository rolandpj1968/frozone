# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Time

        # Wrap MRI utc_offset (Integer or Rational) as a Frozone object.
        def wrap_utc_offset(offset) = offset.is_a?(Integer) ? n2f_int(offset) : make_rational(offset)

        def time_now(context) = time_make(context, Time.now)
        def time_to_f(_, t) = n2f_float(t.raw.to_f)
        def time_to_i(_, t) = n2f_int(t.raw.to_i)
        def time_to_s(_, t) = n2f_str(t.raw.to_s)
        def time_inspect(_, t) = n2f_str(t.raw.inspect)
        def time_usec(_, t) = n2f_int(t.raw.usec)
        def time_nsec(_, t) = n2f_int(t.raw.nsec)
        def time_sec(_, t) = n2f_int(t.raw.sec)
        def time_min(_, t) = n2f_int(t.raw.min)
        def time_hour(_, t) = n2f_int(t.raw.hour)
        def time_mday(_, t) = n2f_int(t.raw.mday)
        def time_month(_, t) = n2f_int(t.raw.month)
        def time_year(_, t) = n2f_int(t.raw.year)
        def time_wday(_, t) = n2f_int(t.raw.wday)
        def time_yday(_, t) = n2f_int(t.raw.yday)
        def time_utc?(_, t) = n2f_bool(t.raw.utc?)
        def time_dup(_, t) = time_preserve_class(t, t.raw.dup)
        def time_utc_offset(_, t) = wrap_utc_offset(t.raw.utc_offset)
        def time_asctime(_, t) = n2f_str(t.raw.asctime)
        def time_ceil(_, t, n) = n2f_time(t.raw.ceil(fint?(n) ? n.raw : 0))
        def time_floor(_, t, n) = n2f_time(t.raw.floor(fint?(n) ? n.raw : 0))
        def time_round(_, t, n) = n2f_time(t.raw.round(fint?(n) ? n.raw : 0))

        def time_load(_, str)
          raw = str.raw
          # MRI's Time._load reads @submicro via C-level internal ivars that can't
          # be reproduced with Ruby-level instance_variable_set. Instead, load the
          # base time (microsecond precision), then add sub-microsecond ns from @nano_num.
          t = Time.send(:_load, raw)
          nano_num = str.get_ivar(:@nano_num)
          if fint?(nano_num)
            ns = nano_num.raw  # sub-microsecond nanoseconds, 0..999
            if ns > 0
              nano_den = str.get_ivar(:@nano_den)
              den = fint?(nano_den) ? nano_den.raw : 1
              t = t + Rational(ns, den * 1_000_000_000)
            end
          end
          n2f_time(t)
        end

        def time_strftime(_, t, format) = n2f_str(t.raw.strftime(format.raw))
        def time_dst?(_, t) = n2f_bool(t.raw.dst?)
        def time_hash(_, t) = n2f_int(t.raw.hash)
        def time_iso8601(_, t, n) = n2f_str(t.raw.iso8601(fint?(n) ? n.raw : 0))
        def time_dump(_, t) = n2f_str(t.raw.send(:_dump, -1))

        # Extract an MRI Numeric from a Frozone value (Integer, Float, or Rational ObjectObject).
        # get_ivar returns FNIL (not MRI nil) when ivar is absent.
        def frozone_to_mri_numeric(obj)
          return obj.raw if fint?(obj) || ffloat?(obj)
          return 0 if fnil?(obj)
          num = obj.get_ivar(:@numerator)
          den = obj.get_ivar(:@denominator)
          # FNIL means the ivar is not set — not a Rational ObjectObject
          return fobj?(obj) ? obj.raw : 0 if fnil?(num) || fnil?(den)
          n = fint?(num) ? num.raw : (fobj?(num) ? num.raw.to_i : 0)
          d = fint?(den) ? den.raw : (fobj?(den) ? den.raw.to_i : 1)
          d == 1 ? n : Rational(n, d)
        end

        # Create a TimeObject, inheriting the subclass from context.the_self when called
        # from a class method (Time.at on a subclass, Time.new on a subclass, etc.).
        def time_make(context, mri_time)
          t = n2f_time(mri_time)
          the_self = context.frame&.the_self
          if the_self.is_a?(ClassObject) && !the_self.equal?(t.class_object)
            t.class_object = the_self
          end
          t
        end

        # Create a TimeObject preserving the class of an existing TimeObject (for instance methods).
        def time_preserve_class(src, mri_time)
          t = n2f_time(mri_time)
          t.class_object = src.class_object unless src.class_object.equal?(t.class_object)
          t
        end

        # time_at_raw: called from pure-Ruby Time.at after argument coercion.
        # t_r: Frozone Numeric (Integer/Float/Rational) or TimeObject; tz: Frozone String/Integer or nil.
        def time_at_raw(context, t_r, tz)
          # Pass TimeObject.raw directly so MRI Time.at(time) preserves the UTC flag.
          mri_r = t_r.is_a?(TimeObject) ? t_r.raw : frozone_to_mri_numeric(t_r)
          t = Time.at(mri_r)
          unless fnil?(tz)
            tz_raw = fstr?(tz) ? tz.raw : frozone_to_mri_numeric(tz).to_i
            t = t.localtime(tz_raw)
          end
          time_make(context, t)
        end

        # Legacy: still used when time_at is called without keyword args.
        def time_at(context, t, subsec = FNIL)
          raw_t = t.is_a?(TimeObject) ? t.raw : Time.at(frozone_to_mri_numeric(t))
          if fnil?(subsec)
            time_make(context, Time.at(raw_t))
          else
            time_make(context, Time.at(raw_t, subsec.raw.to_f))
          end
        end

        def time_mktime(context, year, month, day, hour, min, sec, usec, use_utc, isdst = FNIL)
          y  = frozone_to_mri_numeric(year).to_i
          mo = frozone_to_mri_numeric(month).to_i
          d  = frozone_to_mri_numeric(day).to_i
          h  = frozone_to_mri_numeric(hour).to_i
          mi = frozone_to_mri_numeric(min).to_i
          s  = frozone_to_mri_numeric(sec)   # Rational preserved
          us = frozone_to_mri_numeric(usec)  # Rational preserved
          # 10-arg C-style form with isdst hint for DST disambiguation (local only).
          if !(ftrue?(use_utc) || use_utc == true) &&
             (ftrue?(isdst) || ffalse?(isdst) || isdst == true || isdst == false)
            isdst_val = ftrue?(isdst) || isdst == true
            return time_make(context, Time.local(s, mi, h, d, mo, y, 0, 0, isdst_val, nil))
          end
          # Passing usec=0 explicitly clobbers fractional seconds in sec (Rational).
          # Only pass usec if it's non-zero.
          args = us.zero? ? [y, mo, d, h, mi, s] : [y, mo, d, h, mi, s, us]
          if ftrue?(use_utc) || use_utc == true
            time_make(context, Time.utc(*args))
          else
            time_make(context, Time.local(*args))
          end
        end

        def time_new(context, year, month, day, hour, min, sec, tz)
          if fnil?(year)
            if fnil?(tz)
              return time_make(context, Time.now)
            else
              tz_mri = fstr?(tz) ? tz.raw : frozone_to_mri_numeric(tz)
              tz_val = tz_mri.is_a?(String) || tz_mri.is_a?(Rational) || tz_mri.is_a?(Float) ? tz_mri : tz_mri.to_i
              return time_make(context, Time.now.localtime(tz_val))
            end
          end
          mri_args = [year, month, day, hour, min, sec].map { |a|
            fnil?(a) ? nil : frozone_to_mri_numeric(a)
          }
          if fnil?(tz)
            # Drop trailing nils to use MRI defaults
            trimmed = mri_args.reverse.drop_while(&:nil?).reverse
            time_make(context, Time.new(*trimmed))
          else
            tz_mri = fstr?(tz) ? tz.raw : frozone_to_mri_numeric(tz)
            # Strings, Rationals, Floats pass through as-is; other numerics → int
            tz_val = tz_mri.is_a?(String) || tz_mri.is_a?(Rational) || tz_mri.is_a?(Float) ? tz_mri : tz_mri.to_i
            time_make(context, Time.new(*mri_args, tz_val))
          end
        end

        # time_new_from_string: Time.new("2021-12-25 00:00:00 +09:00", precision:, in:)
        # precision: IntegerObject (9 = ns default) or NilObject (unlimited)
        # in_tz: Frozone String/Integer/Rational or NilObject
        def time_new_from_string(context, str, precision, in_tz)
          mri_str = fstr?(str) ? str.raw : str.to_s
          mri_prec = if fnil?(precision)
                       nil
                     elsif fint?(precision)
                       precision.raw
                     else
                       frozone_to_mri_numeric(precision).to_i
                     end
          opts = {}
          opts[:precision] = mri_prec unless mri_prec == 9
          unless fnil?(in_tz)
            opts[:in] = fstr?(in_tz) ? in_tz.raw : frozone_to_mri_numeric(in_tz)
          end
          reraise(ArgumentError, TypeError) do
            t = opts.empty? ? Time.new(mri_str) : Time.new(mri_str, **opts)
            time_make(context, t)
          end
        end

        def time_minus(_, t, other)
          if other.is_a?(TimeObject)
            n2f_float(t.raw - other.raw)
          else
            n2f_time(t.raw - frozone_to_mri_numeric(other))
          end
        end

        def time_plus(_, t, secs) = reraise(TypeError) do
          raise FrozoneException.make(:TypeError, "can't convert NilClass into an exact number") if fnil?(secs)
          n2f_time(t.raw + frozone_to_mri_numeric(secs))
        end

        def time_to_r(_, t)
          r = begin; t.raw.to_r; rescue; Rational(t.raw.to_i, 1); end
          make_rational(r)
        end

        def time_zone(_, t)
          z = t.raw.zone
          z.nil? || z.empty? ? FNIL : n2f_str(z)
        end

        def time_localtime(_, t, tz = FNIL)
          reraise(TypeError, ArgumentError) do
            if t.frozen_object?
              # localtime() with no arg on an already-local frozen time is a no-op (no error)
              return t if fnil?(tz) && !t.raw.utc?
              raise FrozoneException.make(:FrozenError, "can't modify frozen Time")
            end

            if fnil?(tz)
              t.raw.localtime
            elsif fstr?(tz)
              t.raw.localtime(tz.raw)
            elsif fint?(tz)
              t.raw.localtime(tz.raw)
            elsif ffloat?(tz)
              t.raw.localtime(tz.raw.to_i)
            else
              mri_tz = frozone_to_mri_numeric(tz)
              # Preserve Rational offsets; fall back to integer for other numerics
              tz_val = mri_tz.is_a?(Rational) ? mri_tz : mri_tz.to_i
              t.raw.localtime(tz_val)
            end
            t
          end
        end

        def time_utc(_, t)
          if t.frozen_object?
            return t if t.raw.utc?
            raise FrozoneException.make(:FrozenError, "can't modify frozen Time")
          end
          t.raw.utc
          t
        end

        def time_subsec(_, t)
          r = t.raw.subsec
          r.is_a?(Integer) ? n2f_int(r) : make_rational(r)
        end

      end
    end
  end
end
