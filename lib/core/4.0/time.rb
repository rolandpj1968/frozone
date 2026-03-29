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

  # Coerce a time-constructor arg: strings/to_str via to_i, numerics pass through.
  def self._coerce_time_arg(a)
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

  def self._coerce_int_arg(a)
    return nil if a.nil?
    return a.to_i if a.is_a?(Integer) || a.is_a?(Float) || a.is_a?(Rational)
    return a.to_int if a.respond_to?(:to_int)
    raise TypeError, "can't convert #{a.class} into Integer"
  end

  def self._mktime_args(args, use_utc)
    if args.length == 10
      # C-style: sec, min, hour, mday, mon, year, wday, yday, isdst, tz (wday/yday/tz ignored)
      s  = _coerce_time_arg(args[0])
      mi = _coerce_time_arg(args[1])
      h  = _coerce_time_arg(args[2])
      d  = _coerce_time_arg(args[3])
      mo = _coerce_time_arg(args[4])
      y  = _coerce_time_arg(args[5])
      isdst = args[8]  # pass isdst hint for DST disambiguation
      Intrinsics.time_mktime(y, mo, d, h, mi, s, 0, use_utc, isdst)
    elsif args.length >= 1 && args.length <= 7
      y  = _coerce_time_arg(args[0])
      raise TypeError, "no implicit conversion of NilClass into Integer" if y.nil?
      mo = _coerce_time_arg(args[1]) || 1
      d  = _coerce_time_arg(args[2]) || 1
      h  = _coerce_time_arg(args[3]) || 0
      mi = _coerce_time_arg(args[4]) || 0
      s  = _coerce_time_arg(args[5]) || 0
      us = _coerce_time_arg(args[6]) || 0
      Intrinsics.time_mktime(y, mo, d, h, mi, s, us, use_utc)
    else
      raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 1..7)"
    end
  end

  def self._coerce_tz_arg(tz)
    return nil if tz.nil?
    return tz if tz.is_a?(Integer) || tz.is_a?(Float) || tz.is_a?(Rational) || tz.is_a?(String)
    return tz if tz.respond_to?(:utc_to_local) || tz.respond_to?(:local_to_utc)  # timezone object
    return tz.to_str if tz.respond_to?(:to_str)
    return tz.to_r   if tz.respond_to?(:to_r)
    return tz.to_int if tz.respond_to?(:to_int)
    raise TypeError, "can't convert #{tz.class} into an exact number"
  end

  # Offset from utc_to_local result: re-interpret result's wall-clock display as UTC,
  # subtract the original UTC timestamp.  For non-Time results, use to_i directly.
  def self._utc_to_local_offset(local_t, utc_t)
    if local_t.is_a?(Time)
      Time.utc(local_t.year, local_t.mon, local_t.mday,
               local_t.hour, local_t.min, local_t.sec).to_i - utc_t.to_i
    else
      local_t.respond_to?(:to_i) ? local_t.to_i - utc_t.to_i : 0
    end
  end

  # Offset from local_to_utc result: tentative - utc_result.
  # tentative is a UTC-treated calendar time; utc_result is what local_to_utc returned.
  def self.mktime(*args) = _mktime_args(args, false)
  def self.utc(*args) = _mktime_args(args, true)
  def self.gm(*args) = _mktime_args(args, true)
  def self.local(*args) = _mktime_args(args, false)

  def self._local_to_utc_offset(tentative, utc_result)
    tentative.to_i - (utc_result.respond_to?(:to_i) ? utc_result.to_i : tentative.to_i)
  end

  def self.now(in: nil)
    tz = _coerce_tz_arg(binding.local_variable_get(:in))
    t = Intrinsics.time_now
    return t unless tz
    if tz.respond_to?(:utc_to_local) || tz.respond_to?(:local_to_utc)
      unless tz.respond_to?(:utc_to_local)
        raise TypeError, "can't convert #{tz.class} into an exact number"
      end
      utc_t   = t.utc
      local_t = tz.utc_to_local(utc_t)
      offset  = _utc_to_local_offset(local_t, utc_t)
      r = Intrinsics.time_at_raw(t.to_r, offset)
      r.instance_variable_set(:@frozone_timezone, tz)
      return r
    end
    Intrinsics.time_at_raw(t.to_r, tz)
  end

  def self.at(time_or_secs, subsec = AT_NO_SUBSEC, format = AT_NO_FORMAT, in: nil)
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

    tz = _coerce_tz_arg(binding.local_variable_get(:in))
    if tz.respond_to?(:utc_to_local)
      raw_t_r = t_r.is_a?(Time) ? t_r.to_r : t_r.to_r
      utc_t   = Intrinsics.time_at_raw(raw_t_r, nil).utc
      local_t = tz.utc_to_local(utc_t)
      offset  = _utc_to_local_offset(local_t, utc_t)
      r = Intrinsics.time_at_raw(raw_t_r, offset)
      r.instance_variable_set(:@frozone_timezone, tz)
      return r
    end
    Intrinsics.time_at_raw(t_r, tz)
  end

  def self.new(year = NEW_NO_YEAR, month = nil, day = nil, hour = nil, min = nil, sec = nil, tz = nil, in: nil, precision: NEW_NO_PRECISION)
    in_tz = binding.local_variable_get(:in)
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
      # Time.new() or Time.new(in: tz_obj) — use now
      if effective_tz.respond_to?(:utc_to_local)
        utc_t   = Intrinsics.time_new(nil, nil, nil, nil, nil, nil, nil).utc
        local_t = effective_tz.utc_to_local(utc_t)
        offset  = _utc_to_local_offset(local_t, utc_t)
        t = Intrinsics.time_new(nil, nil, nil, nil, nil, nil, offset)
        t.instance_variable_set(:@frozone_timezone, effective_tz)
        return t
      end
      return Intrinsics.time_new(nil, nil, nil, nil, nil, nil, effective_tz)
    end
    raise TypeError, "no implicit conversion of NilClass into Integer" if year.nil?
    y  = _coerce_time_arg(year)
    mo = _coerce_time_arg(month)
    d  = _coerce_time_arg(day)
    h  = _coerce_time_arg(hour)
    mi = _coerce_time_arg(min)
    s  = _coerce_time_arg(sec)
    if effective_tz.respond_to?(:utc_to_local) || effective_tz.respond_to?(:local_to_utc)
      unless effective_tz.respond_to?(:local_to_utc)
        raise TypeError, "can't convert #{effective_tz.class} into an exact number"
      end
      # Use a UTC-tagged tentative time so to_i gives the raw calendar-value timestamp
      tentative = Intrinsics.time_mktime(y, mo, d, h, mi, s, 0, true)
      utc_t     = effective_tz.local_to_utc(tentative)
      offset    = _local_to_utc_offset(tentative, utc_t)
      t = Intrinsics.time_new(y, mo, d, h, mi, s, offset)
      t.instance_variable_set(:@frozone_timezone, effective_tz)
      return t
    end
    Intrinsics.time_new(y, mo, d, h, mi, s, effective_tz)
  end

  def self._load(str) = Intrinsics.time_load(str)
  private_class_method :_load

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

  def self.zone_offset(zone, year = now.year)
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

  def self._time_zone_utc?(zone)
    zone.match?(/\A(?:-00:00|-0000|-00|UTC|Z|UT)\z/i)
  end
  private_class_method :_time_zone_utc?

  def self._time_force_zone!(t, zone, offset = nil)
    if _time_zone_utc?(zone)
      t.utc
    elsif offset ||= zone_offset(zone)
      t.localtime
      t.localtime(offset) if t.utc_offset != offset
    else
      t.localtime
    end
  end
  private_class_method :_time_force_zone!

  LeapYearMonthDays   = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze
  CommonYearMonthDays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31].freeze

  def self._time_month_days(y, m)
    if ((y % 4 == 0) && (y % 100 != 0)) || (y % 400 == 0)
      LeapYearMonthDays[m - 1]
    else
      CommonYearMonthDays[m - 1]
    end
  end
  private_class_method :_time_month_days

  def self._time_apply_offset(year, mon, day, hour, min, sec, off)
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
  private_class_method :_time_apply_offset

  def self.rfc2822(date)
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
  class << self; alias rfc822 rfc2822; end

  def self.httpdate(date)
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

  def self.xmlschema(time)
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
  class << self; alias iso8601 xmlschema; end

  def to_f = Intrinsics.time_to_f(self)
  def to_i = Intrinsics.time_to_i(self)
  def to_s = Intrinsics.time_to_s(self)
  def to_r = Intrinsics.time_to_r(self)
  def inspect = Intrinsics.time_inspect(self)
  def usec = Intrinsics.time_usec(self)
  def nsec = Intrinsics.time_nsec(self)
  def sec = Intrinsics.time_sec(self)
  def min = Intrinsics.time_min(self)
  def hour = Intrinsics.time_hour(self)
  def mday = Intrinsics.time_mday(self)
  def day = mday
  def month = Intrinsics.time_month(self)
  def mon = month
  def year = Intrinsics.time_year(self)
  def wday = Intrinsics.time_wday(self)
  def yday = Intrinsics.time_yday(self)
  def utc? = Intrinsics.time_utc?(self)
  def gmt? = utc?
  def subsec = Intrinsics.time_subsec(self)
  def dst? = Intrinsics.time_dst?(self)
  def isdst = dst?
  def hash = to_r.hash
  def tv_sec = to_i
  def tv_usec = usec
  def tv_nsec = nsec
  def utc = Intrinsics.time_utc(self)
  def gmtime = utc
  def getutc = Intrinsics.time_dup(self).utc
  def getgm = getutc
  def utc_offset = Intrinsics.time_utc_offset(self)
  def gmt_offset = utc_offset
  def gmtoff = utc_offset
  def dup = Intrinsics.time_dup(self)
  def asctime = Intrinsics.time_asctime(self)
  def ctime = asctime
  def ceil(ndigits = 0)  = Intrinsics.time_ceil(self, ndigits)
  def floor(ndigits = 0) = Intrinsics.time_floor(self, ndigits)
  def round(ndigits = 0) = Intrinsics.time_round(self, ndigits)
  def iso8601(fraction_digits = 0)   = Intrinsics.time_iso8601(self, fraction_digits)
  def xmlschema(fraction_digits = 0) = iso8601(fraction_digits)
  def monday? = wday == 1
  def tuesday? = wday == 2
  def wednesday? = wday == 3
  def thursday? = wday == 4
  def friday? = wday == 5
  def saturday? = wday == 6
  def sunday? = wday == 0
  def to_a = [sec, min, hour, mday, month, year, wday, yday, dst?, zone]
  def eql?(other) = other.is_a?(Time) && to_r == other.to_r
  def instance_variables = super.reject { |iv| iv == :@frozone_timezone }
  def to_time = self
  def httpdate = getutc.strftime('%a, %d %b %Y %T GMT')

  def -(other)
    return Intrinsics.time_minus(self, other) if other.is_a?(Time)
    n = _coerce_exact_number(other)
    result = Intrinsics.time_minus(self, n)
    tz = @frozone_timezone
    result.instance_variable_set(:@frozone_timezone, tz) if tz
    result
  end

  def +(other)
    raise TypeError, "can't convert Time into an exact number" if other.is_a?(Time)
    n = _coerce_exact_number(other)
    result = Intrinsics.time_plus(self, n)
    tz = @frozone_timezone
    result.instance_variable_set(:@frozone_timezone, tz) if tz
    result
  end

  def zone
    tz = @frozone_timezone
    return tz if tz
    Intrinsics.time_zone(self)
  end

  def strftime(format)
    tz = @frozone_timezone
    if tz&.respond_to?(:abbr)
      abbr = tz.abbr(self)&.to_s
      if abbr
        escaped = abbr.gsub('%', '%%')
        new_fmt = format.gsub(/%%|%Z/) { |m| m == '%%' ? '%%' : escaped }
        return Intrinsics.time_strftime(self, new_fmt)
      end
    end
    Intrinsics.time_strftime(self, format)
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
      Intrinsics.time_localtime(self, offset)
      @frozone_timezone = resolved
      return self
    end
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
      # Try reverse comparison (MRI protocol for non-Time args)
      begin
        cmp = other <=> self
        return nil if cmp.nil?
        cmp > 0 ? -1 : (cmp < 0 ? 1 : 0)
      rescue
        nil
      end
    end
  end

  # Instance method rfc2822 formatter (added by require 'time').
  def rfc2822
    strftime('%a, %d %b %Y %T ') << (utc? ? '-0000' : strftime('%z'))
  end
  alias rfc822 rfc2822

  private

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
