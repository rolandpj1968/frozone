# Minimal Date/DateTime stub for Frozone.
# date_core is normally a C extension; this provides enough for gems like csv to load.

class Date
  include Comparable

  ITALY     = 2299161  # Julian day of Gregorian calendar adoption in Italy
  ENGLAND   = 2361222
  JULIAN    = Float::INFINITY
  GREGORIAN = -Float::INFINITY

  MONTHNAMES = [nil] + %w[January February March April May June
                          July August September October November December].freeze
  ABBR_MONTHNAMES = [nil] + %w[Jan Feb Mar Apr May Jun
                                Jul Aug Sep Oct Nov Dec].freeze
  DAYNAMES     = %w[Sunday Monday Tuesday Wednesday Thursday Friday Saturday].freeze
  ABBR_DAYNAMES = %w[Sun Mon Tue Wed Thu Fri Sat].freeze

  def self.valid_date?(y, m, d, sg = ITALY)
    return false if y.nil? || m.nil? || d.nil?
    m = m + 12 if m < 1
    d >= 1 && d <= days_in_month(y, m)
  rescue
    false
  end

  def self.days_in_month(year, month)
    [0, 31, (leap?(year) ? 29 : 28), 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month] || 30
  end

  def self.leap?(year)
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
  end

  def self.today(sg = ITALY)
    t = Time.now
    new(t.year, t.month, t.day)
  end

  def self.new(y = -4712, m = 1, d = 1, sg = ITALY)
    obj = allocate
    obj.__send__(:initialize, y, m, d)
    obj
  end
  class << self; alias civil new; end

  def self.parse(str = '-4712-01-01', comp = true, sg = ITALY)
    str = str.to_s.strip
    if str =~ /\A(\d{4})-(\d{1,2})-(\d{1,2})\z/
      new($1.to_i, $2.to_i, $3.to_i)
    elsif str =~ /\A(\d{1,2})\/(\d{1,2})\/(\d{2,4})\z/
      y = $3.to_i; y += (y < 69 ? 2000 : 1900) if y < 100
      new(y, $1.to_i, $2.to_i)
    elsif str =~ /\A(\w+)\s+(\d{1,2}),?\s+(\d{2,4})\z/
      m = ABBR_MONTHNAMES.index($1.capitalize) || MONTHNAMES.index($1.capitalize) || 1
      y = $3.to_i; y += (y < 69 ? 2000 : 1900) if y < 100
      new(y, m, $2.to_i)
    else
      raise ArgumentError, "invalid date: #{str.inspect}"
    end
  end

  def year  = @year
  def month = @month
  def day   = @day
  alias mon   month
  alias mday  day
  def +(n)     = self.class.new(*jd_to_ymd(jd + n.to_i))
  def succ     = self + 1
  alias next succ
  def leap?    = Date.leap?(@year)
  def to_s     = strftime('%F')
  def inspect  = "#<Date: #{self} ((#{jd}j,0s,0n),+0s,#{ITALY}j)>"
  def to_date  = self
  def to_datetime = DateTime.new(@year, @month, @day)
  def infinite? = false

  def initialize(y = -4712, m = 1, d = 1)
    raise ArgumentError, "invalid date" unless Date.valid_date?(y, m, d)
    @year  = y
    @month = m
    @day   = d
  end

  def jd
    # Gregorian to Julian Day Number
    a = (14 - @month) / 12
    y = @year + 4800 - a
    m = @month + 12 * a - 3
    @day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
  end

  def -(other)
    case other
    when Date then jd - other.jd
    when Numeric then self.class.new(*jd_to_ymd(jd - other.to_i))
    else raise TypeError, "expected numeric or date"
    end
  end

  def <=>(other)
    return nil unless other.is_a?(Date)
    jd <=> other.jd
  end

  def wday
    (jd + 1) % 7
  end

  def yday
    jd - self.class.new(@year, 1, 1).jd + 1
  end

  def strftime(fmt = '%F')
    fmt.gsub(/%[A-Za-z%]/) do |spec|
      case spec
      when '%Y' then '%04d' % @year
      when '%m' then '%02d' % @month
      when '%d' then '%02d' % @day
      when '%F' then '%04d-%02d-%02d' % [@year, @month, @day]
      when '%j' then '%03d' % yday
      when '%e' then '%2d' % @day
      when '%A' then DAYNAMES[wday]
      when '%a' then ABBR_DAYNAMES[wday]
      when '%B' then MONTHNAMES[@month]
      when '%b', '%h' then ABBR_MONTHNAMES[@month]
      when '%%' then '%'
      else spec
      end
    end
  end

  private

  def jd_to_ymd(jd)
    a = jd + 32044
    b = (4 * a + 3) / 146097
    c = a - (b * 146097) / 4
    d = (4 * c + 3) / 1461
    e = c - (1461 * d) / 4
    m = (5 * e + 2) / 153
    day   = e - (153 * m + 2) / 5 + 1
    month = m + 3 - 12 * (m / 10)
    year  = b * 100 + d - 4800 + m / 10
    [year, month, day]
  end
end

class DateTime < Date
  def self.now(sg = Date::ITALY)
    t = Time.now
    new(t.year, t.month, t.day, t.hour, t.min, t.sec)
  end

  def self.parse(str = '-4712-01-01T00:00:00+00:00', comp = true, sg = Date::ITALY)
    if str =~ /\A(\d{4})-(\d{1,2})-(\d{1,2})[T ](\d{1,2}):(\d{1,2}):(\d{1,2})/
      new($1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i)
    else
      d = super(str, comp, sg)
      new(d.year, d.month, d.day)
    end
  end

  def hour    = @hour
  def min     = @minute
  def sec     = @second
  def offset  = @offset
  def zone    = '+00:00'
  def to_date = Date.new(@year, @month, @day)
  def to_datetime = self
  def to_s    = strftime('%FT%T%:z')
  def inspect = "#<DateTime: #{self}>"

  def initialize(y = -4712, m = 1, d = 1, h = 0, min = 0, s = 0, offset = 0)
    super(y, m, d)
    @hour   = h
    @minute = min
    @second = s
    @offset = offset
  end

  def strftime(fmt = '%FT%T%:z')
    super(fmt)
      .gsub('%H', '%02d' % @hour)
      .gsub('%M', '%02d' % @minute)
      .gsub('%S', '%02d' % @second)
      .gsub('%T', '%02d:%02d:%02d' % [@hour, @minute, @second])
      .gsub('%:z', '+00:00')
  end

end
