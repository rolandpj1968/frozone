class Time
  include Comparable

  MONTH_NAMES = {
    'jan' => 1, 'feb' => 2, 'mar' => 3, 'apr' => 4,
    'may' => 5, 'jun' => 6, 'jul' => 7, 'aug' => 8,
    'sep' => 9, 'oct' => 10, 'nov' => 11, 'dec' => 12
  }.freeze

  # Sentinels to distinguish argument not passed from explicit nil/value.
  AT_NO_SUBSEC  = Object.new.freeze
  AT_NO_FORMAT  = Object.new.freeze

  NEW_NO_YEAR      = Object.new.freeze
  NEW_NO_PRECISION = Object.new.freeze

  # Class-method extensions added by require 'time' (ported from MRI time.rb).

  ZoneOffset = {
    'UTC' => 0, 'Z' => 0, 'UT' => 0, 'GMT' => 0,
    'EST' => -5, 'EDT' => -4, 'CST' => -6, 'CDT' => -5,
    'MST' => -7, 'MDT' => -6, 'PST' => -8, 'PDT' => -7,
    'A' => +1, 'B' => +2, 'C' => +3, 'D' => +4,  'E' => +5,  'F' => +6,
    'G' => +7, 'H' => +8, 'I' => +9, 'K' => +10, 'L' => +11, 'M' => +12,
    'N' => -1, 'O' => -2, 'P' => -3, 'Q' => -4,  'R' => -5,  'S' => -6,
    'T' => -7, 'U' => -8, 'V' => -9, 'W' => -10, 'X' => -11, 'Y' => -12,
  }.freeze

  MonthValue = {
    'JAN' => 1, 'FEB' => 2, 'MAR' => 3, 'APR' => 4, 'MAY' => 5, 'JUN' => 6,
    'JUL' => 7, 'AUG' => 8, 'SEP' => 9, 'OCT' => 10, 'NOV' => 11, 'DEC' => 12
  }.freeze

  LeapYearMonthDays   = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze
  CommonYearMonthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze

  class << self
    def mktime(*args) = _mktime_args(args, false)
    def utc(*args) = _mktime_args(args, true)
    def gm(*args) = _mktime_args(args, true)
    def local(*args) = _mktime_args(args, false)
    # Offset from local_to_utc result: tentative - utc_result.
    # tentative is a UTC-treated calendar time; utc_result is what local_to_utc returned.
    def _local_to_utc_offset(tentative, utc_result) = tentative.to_i - (utc_result.respond_to?(:to_i) ? utc_result.to_i : tentative.to_i)

    # Offset from utc_to_local result: re-interpret result's wall-clock display as UTC,
    # subtract the original UTC timestamp.  For non-Time results, use to_i directly.
    def _utc_to_local_offset(local_t, utc_t)
      if local_t.is_a?(Time)
        Time.utc(local_t.year, local_t.mon, local_t.mday,
                 local_t.hour, local_t.min, local_t.sec).to_i - utc_t.to_i
      else
        local_t.respond_to?(:to_i) ? local_t.to_i - utc_t.to_i : 0
      end
    end

    def now(in: nil)
      arr = Intrinsics.os_time_now
      t = Intrinsics.time_make(arr[0], arr[1], arr[2], false)
      tz = Intrinsics.interpreted? ? _coerce_tz_arg(binding.local_variable_get(:in)) : nil
      return t unless tz
      if tz.respond_to?(:utc_to_local) || tz.respond_to?(:local_to_utc)
        unless tz.respond_to?(:utc_to_local)
          raise TypeError, "can't convert #{tz.class} into an exact number"
        end
        utc_t   = t.utc
        local_t = tz.utc_to_local(utc_t)
        offset  = _utc_to_local_offset(local_t, utc_t)
        r = _time_at_raw(t.to_r, offset)
        r.instance_variable_set(:@frozone_timezone, tz)
        return r
      end
      _time_at_raw(t.to_r, tz)
    end

    def at(time_or_secs, subsec = AT_NO_SUBSEC, format = AT_NO_FORMAT, in: nil)
      subsec_given = !subsec.equal?(AT_NO_SUBSEC)
      format_given = !format.equal?(AT_NO_FORMAT)
      subsec = nil unless subsec_given
      format = nil unless format_given

      # Coerce primary argument.
      # String and nil are rejected; when both to_r and to_int present, prefer to_r.
      t_r =
        if time_or_secs.is_a?(Time)
          raise TypeError, "can't convert #{time_or_secs.class} into an exact number" if subsec_given
          time_or_secs  # Pass TimeObject directly so UTC flag is preserved
        elsif time_or_secs.is_a?(Integer) || time_or_secs.is_a?(Float) || time_or_secs.is_a?(Rational)
          time_or_secs
        elsif time_or_secs.is_a?(String) || time_or_secs.nil?
          raise TypeError, "can't convert #{time_or_secs.class} into an exact number"
        elsif time_or_secs.respond_to?(:to_r) && time_or_secs.respond_to?(:to_int)
          time_or_secs.to_r
        elsif time_or_secs.respond_to?(:to_int)
          time_or_secs.to_int
        else
          raise TypeError, "can't convert #{time_or_secs.class} into an exact number"
        end

      if subsec_given
        raise TypeError, "can't convert NilClass into an exact number" if subsec.nil?
        raise TypeError, "can't convert String into an exact number" if subsec.is_a?(String)
        divisor =
          if !format_given
            1_000_000  # default unit: microseconds
          else
            case format
            when :nanosecond, :nsec  then 1_000_000_000
            when :microsecond, :usec then 1_000_000
            when :millisecond        then 1_000
            when :second             then 1
            else raise ArgumentError, "unexpected format: #{format.inspect}"
            end
          end
        sub_r =
          if subsec.is_a?(Integer)
            Rational(subsec, divisor)
          elsif subsec.is_a?(Rational)
            subsec / divisor
          elsif subsec.is_a?(Float)
            subsec.to_r / divisor
          elsif subsec.respond_to?(:to_r)
            subsec.to_r / divisor
          elsif subsec.respond_to?(:to_int)
            Rational(subsec.to_int, divisor)
          else
            raise TypeError, "can't convert #{subsec.class} into an exact number"
          end
        t_r = t_r + sub_r
      end

      tz = Intrinsics.interpreted? ? _coerce_tz_arg(binding.local_variable_get(:in)) : nil
      if tz.respond_to?(:utc_to_local)
        raw_t_r = t_r.is_a?(Time) ? t_r.to_r : t_r.to_r
        utc_t   = _time_at_raw(raw_t_r, nil).utc
        local_t = tz.utc_to_local(utc_t)
        offset  = _utc_to_local_offset(local_t, utc_t)
        r = _time_at_raw(raw_t_r, offset)
        r.instance_variable_set(:@frozone_timezone, tz)
        return r
      end
      _time_at_raw(t_r, tz)
    end

    def new(year = NEW_NO_YEAR, month = nil, day = nil, hour = nil, min = nil, sec = nil, tz = nil, in: nil, precision: NEW_NO_PRECISION)
      in_tz = Intrinsics.interpreted? ? binding.local_variable_get(:in) : nil
      if year.is_a?(String) && month.nil?
        # Ruby 3.2+ ISO-8601 string parsing (only when year is the sole positional arg).
        # Coerce precision to Integer if given.
        prec =
          if precision.equal?(NEW_NO_PRECISION)
            9   # MRI default: nanosecond precision
          elsif precision.nil?
            nil  # unlimited (keep full subsecond from string)
          elsif precision.is_a?(Integer)
            precision
          elsif precision.respond_to?(:to_int)
            precision.to_int
          elsif precision.is_a?(Float) || precision.is_a?(Rational)
            precision.to_i
          else
            raise TypeError, "no implicit conversion of #{precision.class} into Integer"
          end
        return Intrinsics.time_new_from_string(year, prec, _coerce_tz_arg(in_tz))
      end
      raise ArgumentError, "timezone argument given as positional and keyword arguments" if !tz.nil? && !in_tz.nil?
      raw_tz = tz || in_tz
      effective_tz =
        if raw_tz.is_a?(String) && respond_to?(:find_timezone)
          find_timezone(raw_tz)
        else
          _coerce_tz_arg(raw_tz)
        end
      if year.equal?(NEW_NO_YEAR)
        if effective_tz.respond_to?(:utc_to_local)
          utc_t   = now.utc
          local_t = effective_tz.utc_to_local(utc_t)
          offset  = _utc_to_local_offset(local_t, utc_t)
          t = _build_time_with_offset(utc_t.to_i, utc_t.nsec, offset)
          t.instance_variable_set(:@frozone_timezone, effective_tz)
          return t
        end
        return _now_with_tz(effective_tz)
      end
      raise TypeError, "no implicit conversion of NilClass into Integer" if year.nil?
      y  = _coerce_time_arg(year) || 0
      mo = _coerce_time_arg(month) || 1
      d  = _coerce_time_arg(day) || 1
      h  = _coerce_time_arg(hour) || 0
      mi = _coerce_time_arg(min) || 0
      s  = _coerce_time_arg(sec) || 0
      if effective_tz.respond_to?(:utc_to_local) || effective_tz.respond_to?(:local_to_utc)
        unless effective_tz.respond_to?(:local_to_utc)
          raise TypeError, "can't convert #{effective_tz.class} into an exact number"
        end
        tentative = _build_calendar_time(y, mo, d, h, mi, s, 0, true)
        utc_t     = effective_tz.local_to_utc(tentative)
        offset    = _local_to_utc_offset(tentative, utc_t)
        t = _build_calendar_time_with_offset(y, mo, d, h, mi, s, offset)
        t.instance_variable_set(:@frozone_timezone, effective_tz)
        return t
      end
      _build_calendar_time_with_tz(y, mo, d, h, mi, s, effective_tz)
    end

    def zone_offset(zone, year = now.year)
      off = nil
      zone = zone.upcase
      if /\A([+-])(\d\d)(:?)(\d\d)(?:\3(\d\d))?\z/ =~ zone
        off = ($1 == '-' ? -1 : 1) * (($2.to_i * 60 + $4.to_i) * 60 + $5.to_i)
      elsif zone.match?(/\A[+-]\d\d\z/)
        off = zone.to_i * 3600
      elsif ZoneOffset.include?(zone)
        off = ZoneOffset[zone] * 3600
      elsif ((t = local(year, 1, 1)).zone.upcase == zone rescue false)
        off = t.utc_offset
      elsif ((t = local(year, 7, 1)).zone.upcase == zone rescue false)
        off = t.utc_offset
      end
      off
    end

    def rfc2822(date)
      if /\A\s*
          (?:(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s*,\s*)?
          (\d{1,2})\s+
          (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+
          (\d{2,})\s+
          (\d{2})\s*
          :\s*(\d{2})
          (?:\s*:\s*(\d\d))?\s+
          ([+-]\d{4}|
           UT|GMT|EST|EDT|CST|CDT|MST|MDT|PST|PDT|[A-IK-Z])/ix =~ date
        day  = $1.to_i
        mon  = MonthValue[$2.upcase]
        year = $3.to_i
        short_year_p = $3.length <= 3
        hour = $4.to_i
        min  = $5.to_i
        sec  = $6 ? $6.to_i : 0
        zone = $7
        if short_year_p
          year = year < 50 ? 2000 + year : 1900 + year
        end
        off = zone_offset(zone)
        year, mon, day, hour, min, sec = _time_apply_offset(year, mon, day, hour, min, sec, off)
        t = utc(year, mon, day, hour, min, sec)
        _time_force_zone!(t, zone, off)
        t
      else
        raise ArgumentError, "not RFC 2822 compliant date: #{date.inspect}"
      end
    end
    alias rfc822 rfc2822

    def httpdate(date)
      if date.match?(/\A\s*
          (?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),\x20
          (\d{2})\x20
          (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\x20
          (\d{4})\x20
          (\d{2}):(\d{2}):(\d{2})\x20
          GMT
          \s*\z/ix)
        rfc2822(date).utc
      elsif /\A\s*
             (?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\x20
             (\d\d)-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-(\d\d)\x20
             (\d\d):(\d\d):(\d\d)\x20
             GMT
             \s*\z/ix =~ date
        year = $3.to_i
        year = year < 50 ? 2000 + year : 1900 + year
        utc(year, $2, $1.to_i, $4.to_i, $5.to_i, $6.to_i)
      elsif /\A\s*
             (?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\x20
             (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\x20
             (\d\d|\x20\d)\x20
             (\d\d):(\d\d):(\d\d)\x20
             (\d{4})
             \s*\z/ix =~ date
        utc($6.to_i, MonthValue[$1.upcase], $2.to_i, $3.to_i, $4.to_i, $5.to_i)
      else
        raise ArgumentError, "not RFC 2616 compliant date: #{date.inspect}"
      end
    end

    def xmlschema(time)
      if /\A\s*
          (-?\d+)-(\d\d)-(\d\d)
          T
          (\d\d):(\d\d):(\d\d)
          (\.\d+)?
          (Z|[+-]\d\d(?::?\d\d)?)?
          \s*\z/ix =~ time
        year = $1.to_i; mon = $2.to_i; day = $3.to_i
        hour = $4.to_i; min = $5.to_i; sec = $6.to_i
        usec = $7 ? Rational($7) * 1_000_000 : 0
        if $8
          zone = $8
          off  = zone_offset(zone)
          year, mon, day, hour, min, sec = _time_apply_offset(year, mon, day, hour, min, sec, off)
          t = utc(year, mon, day, hour, min, sec, usec)
          _time_force_zone!(t, zone, off)
          t
        else
          local(year, mon, day, hour, min, sec, usec)
        end
      else
        raise ArgumentError, "invalid xmlschema format: #{time.inspect}"
      end
    end
    alias iso8601 xmlschema

    def _coerce_tz_arg(tz)
      return nil if tz.nil?
      return tz if tz.is_a?(Integer) || tz.is_a?(Float) || tz.is_a?(Rational) || tz.is_a?(String)
      return tz if tz.respond_to?(:utc_to_local) || tz.respond_to?(:local_to_utc)  # timezone object
      return tz.to_str if tz.respond_to?(:to_str)
      return tz.to_r   if tz.respond_to?(:to_r)
      return tz.to_int if tz.respond_to?(:to_int)
      raise TypeError, "can't convert #{tz.class} into an exact number"
    end

    private

    # Construct a Time from (Rational/Float/Integer/Time) seconds-since-epoch
    # + offset. Hoisted out of intrinsic_time_at_raw — that stub named a
    # Ruby concept (Rational) the C++ side can't model, so the decomposition
    # lives here and the OS-bound work stays in time_make.
    #
    # offset is whatever Time#at accepts: nil (local), Integer (UTC offset
    # seconds), Symbol/String, or a timezone object (handled at call sites).
    def _time_at_raw(t_r, offset)
      if t_r.is_a?(Time)
        # Preserve UTC flag + sub-second from the input Time.
        sec, nsec = t_r.to_i, t_r.nsec
      else
        # Floor-divide into (sec, nsec). t_r may be Integer/Float/Rational;
        # `to_i` truncates toward zero, so adjust the negative-fractional case.
        sec = t_r.to_i
        sec -= 1 if (t_r - sec) < 0
        frac = t_r - sec
        nsec = (frac * 1_000_000_000).round
        # Rounding can push nsec to a full second; carry.
        if nsec >= 1_000_000_000
          sec += 1
          nsec -= 1_000_000_000
        end
      end
      Intrinsics.time_make(sec, nsec, offset, false)
    end

    # Coerce a time-constructor arg: strings/to_str via to_i, numerics pass through.
    def _coerce_time_arg(a)
      return nil if a.nil?
      return a if a.is_a?(Integer) || a.is_a?(Float) || a.is_a?(Rational)
      if a.is_a?(String)
        m = MONTH_NAMES[a.downcase[0, 3]]
        return m if m
        return a.to_i
      end
      if a.respond_to?(:to_str)
        s = a.to_str
        m = MONTH_NAMES[s.downcase[0, 3]]
        return m if m
        return s.to_i
      end
      return a.to_int if a.respond_to?(:to_int)
      raise TypeError, "can't convert #{a.class} into Integer"
    end

    def _coerce_int_arg(a)
      return nil if a.nil?
      return a.to_i if a.is_a?(Integer) || a.is_a?(Float) || a.is_a?(Rational)
      return a.to_int if a.respond_to?(:to_int)
      raise TypeError, "can't convert #{a.class} into Integer"
    end

    def _mktime_args(args, use_utc)
      if args.length == 10
        s  = _coerce_time_arg(args[0])
        mi = _coerce_time_arg(args[1])
        h  = _coerce_time_arg(args[2])
        d  = _coerce_time_arg(args[3])
        mo = _coerce_time_arg(args[4])
        y  = _coerce_time_arg(args[5])
        _build_calendar_time(y, mo, d, h, mi, s, 0, use_utc)
      elsif args.length >= 1 && args.length <= 7
        y  = _coerce_time_arg(args[0])
        raise TypeError, "no implicit conversion of NilClass into Integer" if y.nil?
        mo = _coerce_time_arg(args[1]) || 1
        d  = _coerce_time_arg(args[2]) || 1
        h  = _coerce_time_arg(args[3]) || 0
        mi = _coerce_time_arg(args[4]) || 0
        s  = _coerce_time_arg(args[5]) || 0
        us = _coerce_time_arg(args[6]) || 0
        _build_calendar_time(y, mo, d, h, mi, s, us, use_utc)
      else
        raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 1..7)"
      end
    end

    # Compose os_mktime + time_make: epoch_sec from calendar fields, then
    # build a Time with the requested subsec and UTC/local mode.
    def _build_calendar_time(y, mo, d, h, mi, s, us, use_utc)
      sec_int = s.to_i
      sec_frac = s.is_a?(Integer) ? 0 : (s - sec_int)
      epoch = Intrinsics.os_mktime(y.to_i, mo.to_i, d.to_i, h.to_i, mi.to_i, sec_int, use_utc)
      ns = (sec_frac * 1_000_000_000).to_i + (us.to_r * 1000).to_i
      while ns >= 1_000_000_000
        ns -= 1_000_000_000
        epoch += 1
      end
      offset = use_utc ? 0 : Intrinsics.os_localtime(epoch)[9]
      Intrinsics.time_make(epoch, ns, offset, use_utc)
    end

    # Build a Time from calendar fields when an explicit UTC-offset is
    # supplied. Integer offset goes through os_mktime as UTC (fields
    # interpreted as UTC, then tagged with the requested offset); other
    # tz values fall back to time_at_raw.
    def _build_calendar_time_with_offset(y, mo, d, h, mi, s, offset)
      sec_int = s.to_i
      sec_frac = s.is_a?(Integer) ? 0 : (s - sec_int)
      epoch = Intrinsics.os_mktime(y.to_i, mo.to_i, d.to_i, h.to_i, mi.to_i, sec_int, true) - offset.to_i
      ns = (sec_frac * 1_000_000_000).to_i
      Intrinsics.time_make(epoch, ns, offset, false)
    end

    def _build_calendar_time_with_tz(y, mo, d, h, mi, s, tz)
      return _build_calendar_time(y, mo, d, h, mi, s, 0, false) if tz.nil?
      return _build_calendar_time(y, mo, d, h, mi, s, 0, true)  if tz.is_a?(String) && _time_zone_utc?(tz)
      return _build_calendar_time_with_offset(y, mo, d, h, mi, s, tz) if tz.is_a?(Integer)
      base = _build_calendar_time(y, mo, d, h, mi, s, 0, true)
      _time_at_raw(base.to_r, tz)
    end

    def _now_with_tz(tz)
      arr = Intrinsics.os_time_now
      return Intrinsics.time_make(arr[0], arr[1], arr[2], false) if tz.nil?
      return Intrinsics.time_make(arr[0], arr[1], tz, false) if tz.is_a?(Integer)
      _time_at_raw(now.to_r, tz)
    end

    def _build_time_with_offset(epoch_sec, nsec, offset) = Intrinsics.time_make(epoch_sec, nsec, offset, false)

    def _load(str) = Intrinsics.time_load(str)

    def _time_zone_utc?(zone) = zone.match?(/\A(?:-00:00|-0000|-00|UTC|Z|UT)\z/i)

    def _time_force_zone!(t, zone, offset = nil)
      if _time_zone_utc?(zone)
        t.utc
      elsif offset ||= zone_offset(zone)
        t.localtime
        t.localtime(offset) if t.utc_offset != offset
      else
        t.localtime
      end
    end

    def _time_month_days(y, m) = (((y % 4 == 0) && (y % 100 != 0)) || (y % 400 == 0) ? LeapYearMonthDays : CommonYearMonthDays)[m - 1]

    def _time_apply_offset(year, mon, day, hour, min, sec, off)
      if off < 0
        off = -off
        off, o = off.divmod(60)
        if o != 0 then sec += o; o, sec = sec.divmod(60); off += o end
        off, o = off.divmod(60)
        if o != 0 then min += o; o, min = min.divmod(60); off += o end
        off, o = off.divmod(24)
        if o != 0 then hour += o; o, hour = hour.divmod(24); off += o end
        if off != 0
          day += off
          days = _time_month_days(year, mon)
          if days && days < day
            mon += 1
            if 12 < mon
              mon = 1
              year += 1
            end
            day = 1
          end
        end
      elsif 0 < off
        off, o = off.divmod(60)
        if o != 0 then sec -= o; o, sec = sec.divmod(60); off -= o end
        off, o = off.divmod(60)
        if o != 0 then min -= o; o, min = min.divmod(60); off -= o end
        off, o = off.divmod(24)
        if o != 0 then hour -= o; o, hour = hour.divmod(24); off -= o end
        if off != 0
          day -= off
          if day < 1
            mon -= 1
            if mon < 1
              year -= 1
              mon = 12
            end
            day = _time_month_days(year, mon)
          end
        end
      end
      [year, mon, day, hour, min, sec]
    end
  end

  def to_i = Intrinsics.time_to_i(self)
  def to_f = to_i + nsec / 1_000_000_000.0
  def to_r = Rational.send(:__construct__, to_i * 1_000_000_000 + nsec, 1_000_000_000)
  def nsec = Intrinsics.time_nsec(self)
  def usec = nsec / 1000
  def utc? = Intrinsics.time_utc_q(self)
  def gmt? = utc?
  def utc_offset = Intrinsics.time_utc_offset(self)
  def gmt_offset = utc_offset
  def gmtoff = utc_offset
  def dup = Intrinsics.time_dup(self)
  def sec = _bdt[0]
  def min = _bdt[1]
  def hour = _bdt[2]
  def mday = _bdt[3]
  def day = mday
  def month = _bdt[4]
  def mon = month
  def year = _bdt[5]
  def wday = _bdt[6]
  def yday = _bdt[7]
  def dst? = _bdt[8]
  def isdst = dst?
  def subsec = nsec == 0 ? 0 : nsec / 1_000_000_000.0
  def hash = to_r.hash
  def tv_sec = to_i
  def tv_usec = usec
  def tv_nsec = nsec
  def gmtime = utc
  def getutc = dup.utc
  def getgm = getutc
  def asctime = strftime('%a %b %e %H:%M:%S %Y')
  def ctime = asctime
  def to_s = strftime(utc? ? '%Y-%m-%d %H:%M:%S UTC' : '%Y-%m-%d %H:%M:%S %z')
  def iso8601(fraction_digits = 0)   = _iso8601(fraction_digits)
  def xmlschema(fraction_digits = 0) = iso8601(fraction_digits)
  def monday? = wday == 1
  def tuesday? = wday == 2
  def wednesday? = wday == 3
  def thursday? = wday == 4
  def friday? = wday == 5
  def saturday? = wday == 6
  def sunday? = wday == 0
  def ceil(ndigits = 0)  = _round_subsec(ndigits, :ceil)
  def floor(ndigits = 0) = _round_subsec(ndigits, :floor)
  def round(ndigits = 0) = _round_subsec(ndigits, :round)
  def to_a = [sec, min, hour, mday, month, year, wday, yday, dst?, zone]
  def eql?(other) = other.is_a?(Time) && to_r == other.to_r
  def instance_variables = super.reject { |iv| iv == :@frozone_timezone || iv == :@bdt }
  def to_time = self
  def httpdate = getutc.strftime('%a, %d %b %Y %T GMT')

  def utc
    @bdt = nil
    Intrinsics.time_utc(self)
  end

  def inspect
    body = strftime('%Y-%m-%d %H:%M:%S')
    ns = nsec
    body = "#{body}.#{format('%09d', ns).sub(/0+\z/, '')}" unless ns == 0
    "#{body} #{utc? ? 'UTC' : strftime('%z')}"
  end

  def -(other)
    return _diff_time(other) if other.is_a?(Time)
    _shift(_coerce_exact_number(other), -1)
  end

  def +(other)
    raise TypeError, "can't convert Time into an exact number" if other.is_a?(Time)
    _shift(_coerce_exact_number(other), 1)
  end

  def zone
    tz = @frozone_timezone
    return tz if tz
    z = _bdt[10]
    z.empty? ? nil : z
  end

  def strftime(format)
    tz = @frozone_timezone
    if tz&.respond_to?(:abbr)
      abbr = tz.abbr(self)&.to_s
      if abbr
        escaped = abbr.gsub('%', '%%')
        new_fmt = format.gsub(/%%|%Z/) { |m| m == '%%' ? '%%' : escaped }
        return Intrinsics.os_strftime(new_fmt, to_i, utc_offset, utc?)
      end
    end
    Intrinsics.os_strftime(format, to_i, utc_offset, utc?)
  end

  def localtime(tz = nil)
    resolved =
      if tz.is_a?(String) && self.class.respond_to?(:find_timezone)
        self.class.find_timezone(tz)
      else
        Time._coerce_tz_arg(tz)
      end
    if resolved.respond_to?(:utc_to_local) || resolved.respond_to?(:local_to_utc)
      unless resolved.respond_to?(:utc_to_local)
        raise TypeError, "can't convert #{resolved.class} into an exact number"
      end
      utc_t   = getutc
      local_t = resolved.utc_to_local(utc_t)
      offset  = Time._utc_to_local_offset(local_t, utc_t)
      @bdt = nil
      Intrinsics.time_localtime(self, offset)
      @frozone_timezone = resolved
      return self
    end
    @bdt = nil
    Intrinsics.time_localtime(self, resolved)
  end

  def getlocal(tz = nil)
    t = Intrinsics.time_dup(self)
    resolved =
      if tz.is_a?(String) && self.class.respond_to?(:find_timezone)
        self.class.find_timezone(tz)
      else
        Time._coerce_tz_arg(tz)
      end
    if resolved.respond_to?(:utc_to_local) || resolved.respond_to?(:local_to_utc)
      unless resolved.respond_to?(:utc_to_local)
        raise TypeError, "can't convert #{resolved.class} into an exact number"
      end
      utc_t   = t.getutc
      local_t = resolved.utc_to_local(utc_t)
      offset  = Time._utc_to_local_offset(local_t, utc_t)
      Intrinsics.time_localtime(t, offset)
      t.instance_variable_set(:@frozone_timezone, resolved)
      return t
    end
    Intrinsics.time_localtime(t, resolved)
  end

  def deconstruct_keys(keys)
    unless keys.nil? || keys.is_a?(Array)
      raise TypeError, "wrong argument type #{keys.class} (expected Array or nil)"
    end
    h = { year: year, month: month, day: mday, yday: yday, wday: wday,
          hour: hour, min: min, sec: sec, subsec: subsec, dst: dst?, zone: zone }
    keys.nil? ? h : h.slice(*keys)
  end

  def <=>(other)
    if other.is_a?(Time)
      to_r <=> other.to_r
    else
      begin
        cmp = other <=> self
        return nil if cmp.nil?
        cmp > 0 ? -1 : (cmp < 0 ? 1 : 0)
      rescue
        nil
      end
    end
  end

  def rfc2822
    strftime('%a, %d %b %Y %T ') << (utc? ? '-0000' : strftime('%z'))
  end
  alias rfc822 rfc2822

  private

  # ISO 8601 / xmlschema representation. Hoisted out of intrinsic_time_iso8601
  # — strftime + sprintf is all the work; no need to be in C++.
  # fraction_digits controls sub-second precision: 0 omits, N includes .NNNN
  # rounded to N digits. zone tail: "Z" for UTC, "+HH:MM"/"-HH:MM" otherwise.
  def _iso8601(fraction_digits)
    base = strftime('%Y-%m-%dT%H:%M:%S')
    frac =
      if fraction_digits.to_i > 0
        n = fraction_digits.to_i
        # Round nsec to n digits (nsec has 9 digits of precision).
        if n >= 9
          ".%09d" % nsec
        else
          scale = 10 ** (9 - n)
          ".%0*d" % [n, (nsec + scale / 2) / scale]
        end
      else
        ''
      end
    zone =
      if utc?
        'Z'
      else
        off = utc_offset
        sign = off < 0 ? '-' : '+'
        abs = off.abs
        '%s%02d:%02d' % [sign, abs / 3600, (abs % 3600) / 60]
      end
    base + frac + zone
  end

  def _bdt
    cached = @bdt
    return cached if cached
    @bdt = utc? ? Intrinsics.os_gmtime(to_i) : Intrinsics.os_localtime(to_i)
  end

  # delta is Integer/Float/Rational seconds; sign is +1 or -1.
  def _shift(delta, sign)
    new_sec = to_i + (sign * delta.to_i)
    new_nsec = nsec
    frac = delta.is_a?(Integer) ? 0 : (delta - delta.to_i)
    if frac != 0
      total_ns = new_nsec + sign * (frac * 1_000_000_000).to_i
      while total_ns < 0
        total_ns += 1_000_000_000
        new_sec -= 1
      end
      while total_ns >= 1_000_000_000
        total_ns -= 1_000_000_000
        new_sec += 1
      end
      new_nsec = total_ns
    end
    result = Intrinsics.time_make(new_sec, new_nsec, utc_offset, utc?)
    tz = @frozone_timezone
    result.instance_variable_set(:@frozone_timezone, tz) if tz
    result
  end

  def _diff_time(other)
    (to_i - other.to_i) + (nsec - other.nsec) / 1_000_000_000.0
  end

  def _round_subsec(ndigits, mode)
    n = ndigits.to_i
    return dup if n >= 9
    divisor = 10**(9 - n)
    ns = nsec
    kept = case mode
           when :floor then (ns / divisor) * divisor
           when :ceil  then ((ns + divisor - 1) / divisor) * divisor
           else
             k = ns / divisor
             k += 1 if (ns % divisor) * 2 >= divisor
             k * divisor
           end
    new_sec = to_i
    if kept >= 1_000_000_000
      kept -= 1_000_000_000
      new_sec += 1
    end
    Intrinsics.time_make(new_sec, kept, utc_offset, utc?)
  end

  def _coerce_exact_number(val)
    raise TypeError, "can't convert #{val.class} into an exact number" if val.nil? || val.is_a?(String)
    return val if val.is_a?(Integer) || val.is_a?(Float) || val.is_a?(Rational)
    return val.to_r if val.respond_to?(:to_r)
    return val.to_int if val.respond_to?(:to_int)
    raise TypeError, "can't convert #{val.class} into an exact number"
  end

  def _dump(limit = -1)
    str = Intrinsics.time_dump(self)
    # Copy the Time object's own instance variables onto the dump string (MRI
    # includes them in the _dump IVAR block, alongside zone/offset).
    instance_variables.each do |iv|
      str.instance_variable_set(iv, instance_variable_get(iv))
    end
    # Attach zone and offset as bare-name marshal ivars (no @ prefix) using a
    # singleton method, matching MRI Marshal behaviour where zone/offset are
    # written as :zone/:offset (not :@zone/:@offset) in the IVAR list.
    z = zone
    off = utc? ? nil : utc_offset
    nano_ns = nsec % 1000
    pairs = []
    z_str = z.is_a?(String) ? z : (z ? z.name : nil)
    pairs << :zone << z_str if z_str && !z_str.empty?
    pairs << :offset << off if off && off != 0
    if nano_ns != 0
      d0 = nano_ns / 100
      d1 = (nano_ns / 10) % 10
      d2 = nano_ns % 10
      b0 = (d0 << 4) | d1
      b1 = d2 << 4
      # Packed BCD: each digit in a nibble, right-padded with 0, trailing zero bytes stripped.
      submicro = b1 == 0 ? b0.chr(Encoding::ASCII_8BIT) : (b0.chr(Encoding::ASCII_8BIT) + b1.chr(Encoding::ASCII_8BIT))
      pairs << :nano_num << nano_ns << :nano_den << 1 << :submicro << submicro
    end
    unless pairs.empty?
      str.define_singleton_method(:__marshal_time_ivars__) { pairs }
    end
    str
  end
end
