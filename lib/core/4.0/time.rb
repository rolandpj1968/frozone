class Time
  include Comparable

  def self.now(in: nil)
    tz = binding.local_variable_get(:in)
    t = Intrinsics.time_now
    tz ? Intrinsics.time_at_raw(t.to_r, tz) : t
  end

  MONTH_NAMES = {
    'jan' => 1, 'feb' => 2, 'mar' => 3, 'apr' => 4,
    'may' => 5, 'jun' => 6, 'jul' => 7, 'aug' => 8,
    'sep' => 9, 'oct' => 10, 'nov' => 11, 'dec' => 12
  }.freeze

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

  # Sentinels to distinguish argument not passed from explicit nil/value.
  AT_NO_SUBSEC  = Object.new.freeze
  AT_NO_FORMAT  = Object.new.freeze

  def self.at(time_or_secs, subsec = AT_NO_SUBSEC, format = AT_NO_FORMAT, in: nil)
    subsec_given = !subsec.equal?(AT_NO_SUBSEC)
    format_given = !format.equal?(AT_NO_FORMAT)
    subsec = nil unless subsec_given
    format = nil unless format_given

    # Coerce primary argument.
    # String and nil are rejected; when both to_r and to_int present, prefer to_r.
    t_r = if time_or_secs.is_a?(Time)
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
      divisor = if !format_given
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
      sub_r = if subsec.is_a?(Integer)
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

    tz = binding.local_variable_get(:in)
    Intrinsics.time_at_raw(t_r, tz)
  end

  def self._coerce_int_arg(a)
    return nil if a.nil?
    return a.to_i if a.is_a?(Integer) || a.is_a?(Float) || a.is_a?(Rational)
    return a.to_int if a.respond_to?(:to_int)
    raise TypeError, "can't convert #{a.class} into Integer"
  end

  def self._mktime_args(args, use_utc)
    if args.length == 10
      # C-style: sec, min, hour, mday, mon, year, wday, yday, isdst, tz (last 4 ignored)
      s = _coerce_time_arg(args[0])
      mi = _coerce_time_arg(args[1])
      h  = _coerce_time_arg(args[2])
      d  = _coerce_time_arg(args[3])
      mo = _coerce_time_arg(args[4])
      y  = _coerce_time_arg(args[5])
      Intrinsics.time_mktime(y, mo, d, h, mi, s, 0, use_utc)
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

  def self.mktime(*args) = _mktime_args(args, false)
  def self.utc(*args)    = _mktime_args(args, true)
  def self.gm(*args)     = _mktime_args(args, true)
  def self.local(*args)  = _mktime_args(args, false)

  NEW_NO_YEAR = Object.new.freeze

  def self.new(year = NEW_NO_YEAR, month = nil, day = nil, hour = nil, min = nil, sec = nil, tz = nil, in: nil)
    effective_tz = _coerce_tz_arg(tz || binding.local_variable_get(:in))
    if year.equal?(NEW_NO_YEAR)
      return Intrinsics.time_new(nil, nil, nil, nil, nil, nil, effective_tz)
    end
    raise TypeError, "no implicit conversion of NilClass into Integer" if year.nil?
    y  = _coerce_time_arg(year)
    mo = _coerce_time_arg(month)
    d  = _coerce_time_arg(day)
    h  = _coerce_time_arg(hour)
    mi = _coerce_time_arg(min)
    s  = _coerce_time_arg(sec)
    Intrinsics.time_new(y, mo, d, h, mi, s, effective_tz)
  end

  def -(other)
    return Intrinsics.time_minus(self, other) if other.is_a?(Time)
    raise TypeError, "can't convert #{other.class} into an exact number" if other.nil? || other.is_a?(String)
    n = if other.is_a?(Integer) || other.is_a?(Float) || other.is_a?(Rational)
      other
    elsif other.respond_to?(:to_r)
      other.to_r
    elsif other.respond_to?(:to_int)
      other.to_int
    else
      raise TypeError, "can't convert #{other.class} into an exact number"
    end
    Intrinsics.time_minus(self, n)
  end

  def +(other)
    raise TypeError, "can't convert Time into an exact number" if other.is_a?(Time)
    raise TypeError, "can't convert #{other.class} into an exact number" if other.nil?
    raise TypeError, "can't convert String into an exact number" if other.is_a?(String)
    n = if other.is_a?(Integer) || other.is_a?(Float) || other.is_a?(Rational)
      other
    elsif other.respond_to?(:to_r)
      other.to_r
    elsif other.respond_to?(:to_int)
      other.to_int
    else
      raise TypeError, "can't convert #{other.class} into an exact number"
    end
    Intrinsics.time_plus(self, n)
  end
  def to_f      = Intrinsics.time_to_f(self)
  def to_i      = Intrinsics.time_to_i(self)
  def to_s      = Intrinsics.time_to_s(self)
  def to_r      = Intrinsics.time_to_r(self)
  def inspect   = Intrinsics.time_inspect(self)
  def usec      = Intrinsics.time_usec(self)
  def nsec      = Intrinsics.time_nsec(self)
  def sec       = Intrinsics.time_sec(self)
  def min       = Intrinsics.time_min(self)
  def hour      = Intrinsics.time_hour(self)
  def mday      = Intrinsics.time_mday(self)
  def day       = mday
  def month     = Intrinsics.time_month(self)
  def mon       = month
  def year      = Intrinsics.time_year(self)
  def wday      = Intrinsics.time_wday(self)
  def yday      = Intrinsics.time_yday(self)
  def zone      = Intrinsics.time_zone(self)
  def utc?      = Intrinsics.time_utc?(self)
  def gmt?      = utc?
  def subsec    = Intrinsics.time_subsec(self)
  def strftime(format) = Intrinsics.time_strftime(self, format)
  def dst?      = Intrinsics.time_dst?(self)
  def isdst     = dst?
  def hash      = Intrinsics.time_hash(self)
  def tv_sec    = to_i
  def tv_usec   = usec
  def tv_nsec   = nsec

  def utc           = Intrinsics.time_utc(self)
  def gmtime        = utc
  def getutc        = Intrinsics.time_dup(self).utc
  def getgm         = getutc
  def utc_offset    = Intrinsics.time_utc_offset(self)
  def gmt_offset    = utc_offset
  def gmtoff        = utc_offset

  def self._coerce_tz_arg(tz)
    return tz if tz.nil? || tz.is_a?(Integer) || tz.is_a?(Float) || tz.is_a?(Rational) || tz.is_a?(String)
    return tz.to_str if tz.respond_to?(:to_str)
    return tz.to_r   if tz.respond_to?(:to_r)
    return tz.to_int if tz.respond_to?(:to_int)
    tz
  end

  def localtime(tz = nil) = Intrinsics.time_localtime(self, Time._coerce_tz_arg(tz))
  def getlocal(tz = nil)  = Intrinsics.time_localtime(Intrinsics.time_dup(self), Time._coerce_tz_arg(tz))

  def dup = Intrinsics.time_dup(self)

  def asctime = Intrinsics.time_asctime(self)
  def ctime   = asctime

  def ceil(ndigits = 0)  = Intrinsics.time_ceil(self, ndigits)
  def floor(ndigits = 0) = Intrinsics.time_floor(self, ndigits)
  def round(ndigits = 0) = Intrinsics.time_round(self, ndigits)

  def iso8601(fraction_digits = 0)   = Intrinsics.time_iso8601(self, fraction_digits)
  def xmlschema(fraction_digits = 0) = iso8601(fraction_digits)

  def monday?    = wday == 1
  def tuesday?   = wday == 2
  def wednesday? = wday == 3
  def thursday?  = wday == 4
  def friday?    = wday == 5
  def saturday?  = wday == 6
  def sunday?    = wday == 0

  def to_a
    [sec, min, hour, mday, month, year, wday, yday, dst?, zone]
  end

  def deconstruct_keys(keys)
    unless keys.nil? || keys.is_a?(Array)
      raise TypeError, "wrong argument type #{keys.class} (expected Array or nil)"
    end
    h = {year: year, month: month, day: mday, yday: yday, wday: wday,
         hour: hour, min: min, sec: sec, subsec: subsec, dst: dst?, zone: zone}
    keys.nil? ? h : h.slice(*keys)
  end

  private

  def _dump(limit = -1)
    Intrinsics.time_dump(self)
  end

  public

  def self._load(str)
    Intrinsics.time_load(str)
  end
  private_class_method :_load

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

  def eql?(other)
    return false unless other.is_a?(Time)
    to_r == other.to_r
  end
end
