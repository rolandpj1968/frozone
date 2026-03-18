class Regexp
  IGNORECASE   = 1
  EXTENDED     = 2
  MULTILINE    = 4
  FIXEDENCODING = 16
  NOENCODING   = 32

  def ==(v) = Intrinsics.regexp_eq(self, v)
  alias eql? ==
  def source = Intrinsics.regexp_source(self)
  def options = Intrinsics.regexp_options(self)
  def inspect = Intrinsics.regexp_inspect(self)
  def to_s = Intrinsics.regexp_to_s(self)
  def casefold? = Intrinsics.regexp_casefold(self)
  def fixed_encoding? = Intrinsics.regexp_fixed_encoding(self)
  def encoding = Intrinsics.regexp_encoding(self)
  def named_captures = Intrinsics.regexp_named_captures(self)
  def names = Intrinsics.regexp_names(self)

  def match(str, pos = 0) = Intrinsics.regexp_match(self, str, pos)
  def match?(str, pos = 0) = Intrinsics.regexp_match_bool(self, str, pos)

  def ===(str)
    if str.is_a?(String)
      !match(str).nil?
    elsif str.is_a?(Symbol)
      !match(str.to_s).nil?
    elsif str.respond_to?(:to_str)
      result = str.to_str
      return false unless result.is_a?(String)
      !match(result).nil?
    else
      false
    end
  end

  def =~(str) = Intrinsics.regexp_match_index(self, str)
  def ~() = Intrinsics.regexp_tilde(self)

  def hash = Intrinsics.regexp_hash(self)

  def linear_time? = Intrinsics.regexp_linear_time_q(self)

  def self.escape(str) = Intrinsics.regexp_escape(str)
  def self.quote(str)  = Intrinsics.regexp_escape(str)
  def self.union(*patterns) = Intrinsics.regexp_union(patterns)
  def self.last_match(n = nil) = Intrinsics.regexp_last_match(n)
  def self.linear_time?(pattern, flags = nil) = Intrinsics.regexp_class_linear_time_q(pattern, flags)
  def self.try_convert(obj)
    return obj if obj.is_a?(Regexp)
    nil
  end

  def self.new(pattern, options = nil, **kw_opts) = Intrinsics.regexp_new(pattern, options)
  def self.compile(pattern, options = nil, **kw_opts) = Intrinsics.regexp_new(pattern, options)

  def self.timeout     = Intrinsics.regexp_timeout(self)
  def self.timeout=(v) = Intrinsics.regexp_set_timeout(self, v)
end
