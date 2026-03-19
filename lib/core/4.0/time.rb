class Time
  include Comparable

  def self.now       = Intrinsics.time_now
  def self.at(t, subsec = nil) = Intrinsics.time_at(t, subsec)
  def self.mktime(year, month = 1, day = 1, hour = 0, min = 0, sec = 0, usec = 0) = Intrinsics.time_mktime(year, month, day, hour, min, sec, usec, false)
  def self.utc(year, month = 1, day = 1, hour = 0, min = 0, sec = 0, usec = 0) = Intrinsics.time_mktime(year, month, day, hour, min, sec, usec, true)
  def self.gm(year, month = 1, day = 1, hour = 0, min = 0, sec = 0, usec = 0) = Intrinsics.time_mktime(year, month, day, hour, min, sec, usec, true)
  def self.local(year, month = 1, day = 1, hour = 0, min = 0, sec = 0, usec = 0) = Intrinsics.time_mktime(year, month, day, hour, min, sec, usec, false)
  def self.new(year = nil, month = nil, day = nil, hour = nil, min = nil, sec = nil, tz = nil) = Intrinsics.time_new(year, month, day, hour, min, sec, tz)

  def -(other)  = Intrinsics.time_minus(self, other)
  def +(other)  = Intrinsics.time_plus(self, other)
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
  def localtime = Intrinsics.time_localtime(self)
  def utc       = Intrinsics.time_utc(self)
  def gmtime    = utc
  def getlocal  = localtime
  def getutc    = utc
  def getgm     = utc
  def tv_sec    = to_i
  def tv_usec   = usec
  def tv_nsec   = nsec
  def subsec    = Intrinsics.time_subsec(self)
  def strftime(format) = Intrinsics.time_strftime(self, format)
  def dst?      = Intrinsics.time_dst?(self)
  def isdst     = dst?
  def hash      = Intrinsics.time_hash(self)

  def <=>(other)
    return nil unless other.is_a?(Time)
    to_f <=> other.to_f
  end

  def eql?(other)
    return false unless other.is_a?(Time)
    to_r == other.to_r
  end
end
