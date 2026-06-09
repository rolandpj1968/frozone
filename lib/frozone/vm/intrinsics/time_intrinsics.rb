# frozen_string_literal: true

module Frozone
  module Vm
    module Intrinsics
      class << self
        # Time — minimal OS-bound primitives mirroring cpp/runtime/intrinsics/time_intrinsics.hpp.
        #
        # The interpreter still backs each TimeObject with an MRI Time in
        # TimeObject.raw, so these primitives delegate to MRI Time methods
        # rather than calling localtime_r / mktime / strftime directly.

        def os_time_now(_)
          ts = Time.now
          n2f_arr([n2f_int(ts.to_i), n2f_int(ts.nsec), n2f_int(ts.utc_offset)])
        end

        def os_localtime(_, sec)
          t = Time.at(sec.raw)
          tm_to_arr(t)
        end

        def os_gmtime(_, sec)
          t = Time.at(sec.raw).utc
          tm_to_arr(t)
        end

        def os_mktime(_, year, month, mday, hour, min, sec, use_utc)
          t = ftrue?(use_utc) ? Time.utc(year.raw, month.raw, mday.raw, hour.raw, min.raw, sec.raw)
                              : Time.local(year.raw, month.raw, mday.raw, hour.raw, min.raw, sec.raw)
          n2f_int(t.to_i)
        end

        def os_strftime(_, fmt, sec, utc_offset, is_utc)
          t = ftrue?(is_utc) ? Time.at(sec.raw).utc : Time.at(sec.raw).localtime(utc_offset.raw)
          n2f_str(t.strftime(fmt.raw))
        end

        def time_make(context, sec, nsec, utc_offset, is_utc)
          mri = Time.at(sec.raw, nsec.raw, :nsec)
          mri = ftrue?(is_utc) ? mri.utc : mri.localtime(utc_offset.raw)
          time_make_obj(context, mri)
        end

        def time_to_i(_, t) = n2f_int(t.raw.to_i)
        def time_nsec(_, t) = n2f_int(t.raw.nsec)
        def time_utc_q(_, t) = n2f_bool(t.raw.utc?)
        def time_utc_offset(_, t) = wrap_utc_offset(t.raw.utc_offset)
        def time_dup(_, t) = time_preserve_class(t, t.raw.dup)

        def time_utc(_, t)
          if t.frozen_object?
            return t if t.raw.utc?
            raise FrozoneException.make(:FrozenError, "can't modify frozen Time")
          end
          t.raw.utc
          t
        end

        def time_localtime(_, t, tz = FNIL)
          reraise(TypeError, ArgumentError) do
            if t.frozen_object?
              return t if fnil?(tz) && !t.raw.utc?
              raise FrozoneException.make(:FrozenError, "can't modify frozen Time")
            end
            if fnil?(tz)
              t.raw.localtime
            elsif fstr?(tz) || fint?(tz)
              t.raw.localtime(tz.raw)
            elsif ffloat?(tz)
              t.raw.localtime(tz.raw.to_i)
            else
              mri_tz = frozone_to_mri_numeric(tz)
              tz_val = mri_tz.is_a?(Rational) ? mri_tz : mri_tz.to_i
              t.raw.localtime(tz_val)
            end
            t
          end
        end

        # Wrap MRI utc_offset (Integer or Rational) as a Frozone object.
        def wrap_utc_offset(offset) = offset.is_a?(Integer) ? n2f_int(offset) : make_rational(offset)

        # ---- Deferred stubs (still delegated to MRI Time) ------------------

        def time_to_r(_, t)
          r = begin; t.raw.to_r; rescue; Rational(t.raw.to_i, 1); end
          make_rational(r)
        end

        def time_iso8601(_, t, n) = n2f_str(t.raw.iso8601(fint?(n) ? n.raw : 0))
        def time_dump(_, t) = n2f_str(t.raw.send(:_dump, -1))

        def time_load(_, str)
          raw = str.raw
          # MRI's Time._load reads @submicro via C-level internal ivars that can't
          # be reproduced with Ruby-level instance_variable_set. Instead, load the
          # base time (microsecond precision), then add sub-microsecond ns from @nano_num.
          t = Time.send(:_load, raw)
          nano_num = str.get_ivar(:@nano_num)
          if fint?(nano_num)
            ns = nano_num.raw
            if ns > 0
              nano_den = str.get_ivar(:@nano_den)
              den = fint?(nano_den) ? nano_den.raw : 1
              t = t + Rational(ns, den * 1_000_000_000)
            end
          end
          n2f_time(t)
        end

        # time_at_raw: called from pure-Ruby Time.at after argument coercion.
        # t_r: Frozone Numeric (Integer/Float/Rational) or TimeObject; tz: Frozone String/Integer or nil.
        def time_at_raw(context, t_r, tz)
          mri_r = t_r.is_a?(TimeObject) ? t_r.raw : frozone_to_mri_numeric(t_r)
          t = Time.at(mri_r)
          unless fnil?(tz)
            tz_raw = fstr?(tz) ? tz.raw : frozone_to_mri_numeric(tz).to_i
            t = t.localtime(tz_raw)
          end
          time_make_obj(context, t)
        end

        # time_new_from_string: Time.new("2021-12-25 00:00:00 +09:00", precision:, in:)
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
            time_make_obj(context, t)
          end
        end

        # ---- Internal helpers ---------------------------------------------

        # Extract an MRI Numeric from a Frozone value (Integer, Float, or Rational ObjectObject).
        def frozone_to_mri_numeric(obj)
          return obj.raw if fint?(obj) || ffloat?(obj)
          return 0 if fnil?(obj)
          num = obj.get_ivar(:@numerator)
          den = obj.get_ivar(:@denominator)
          return fobj?(obj) ? obj.raw : 0 if fnil?(num) || fnil?(den)
          n = fint?(num) ? num.raw : (fobj?(num) ? num.raw.to_i : 0)
          d = fint?(den) ? den.raw : (fobj?(den) ? den.raw.to_i : 1)
          d == 1 ? n : Rational(n, d)
        end

        # Create a TimeObject, inheriting the subclass from context.the_self when called
        # from a class method (Time.at on a subclass, Time.new on a subclass, etc.).
        def time_make_obj(context, mri_time)
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

        private

        # Build the 11-tuple Frozone Array from an MRI Time:
        # [sec, min, hour, mday, month_1based, year_full, wday, yday_1based,
        #  isdst, utc_offset_sec, zone_string].
        def tm_to_arr(t)
          n2f_arr([
            n2f_int(t.sec), n2f_int(t.min), n2f_int(t.hour),
            n2f_int(t.mday), n2f_int(t.month), n2f_int(t.year),
            n2f_int(t.wday), n2f_int(t.yday),
            n2f_bool(t.dst?), n2f_int(t.utc_offset),
            n2f_str(t.zone || '')
          ])
        end
      end
    end
  end
end
