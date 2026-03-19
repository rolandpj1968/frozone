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
  def match?(str, pos = 0) = Intrinsics.regexp_match_bool(self, str, pos)
  def =~(str) = Intrinsics.regexp_match_index(self, str)
  def ~() = Intrinsics.regexp_tilde(self)
  def hash = Intrinsics.regexp_hash(self)
  def linear_time? = Intrinsics.regexp_linear_time_q(self)
  def self.escape(str) = Intrinsics.regexp_escape(str)
  def self.quote(str) = Intrinsics.regexp_escape(str)
  def self.union(*patterns) = Intrinsics.regexp_union(patterns)
  def self.last_match(n = nil) = Intrinsics.regexp_last_match(n)
  def self.linear_time?(pattern, flags = nil) = Intrinsics.regexp_class_linear_time_q(pattern, flags)

  def match(str, pos = 0, &block)
    md = Intrinsics.regexp_match(self, str, pos)
    if block && md
      block.call(md)
    else
      md
    end
  end

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

  def self.try_convert(obj)
    return obj if obj.is_a?(Regexp)
    return nil unless obj.respond_to?(:to_regexp)
    result = obj.to_regexp
    raise TypeError, "can't convert #{obj.class} into Regexp (#{obj.class}#to_regexp gives #{result.class})" unless result.is_a?(Regexp)
    result
  end

  def initialize(pattern = nil, options = nil)
    raise FrozenError, "can't modify frozen Regexp: #{inspect}" if frozen?
    raise TypeError, "already initialized regexp" unless Intrinsics.regexp_newly_created_q(self)
  end
  private :initialize

  def self.new(pattern, options = nil, **kw_opts) = Intrinsics.regexp_new(self, pattern, options, kw_opts)
  def self.compile(pattern, options = nil, **kw_opts) = Intrinsics.regexp_new(self, pattern, options, kw_opts)
  def self.timeout = Intrinsics.regexp_timeout(self)
  def self.timeout=(v) = Intrinsics.regexp_set_timeout(self, v)

  def dup
    Regexp.new(source, options)
  end

  def clone(freeze: nil)
    c = dup
    should_freeze = freeze.nil? ? frozen? : freeze
    raise ArgumentError, "can't unfreeze Regexp" if freeze == false
    c.freeze if should_freeze
    c
  end
  class TimeoutError < RegexpError; end
end
