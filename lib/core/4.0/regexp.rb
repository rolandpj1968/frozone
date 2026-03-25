class Regexp
  IGNORECASE   = 1
  EXTENDED     = 2
  MULTILINE    = 4
  FIXEDENCODING = 16
  NOENCODING   = 32

  def ==(v) = v.is_a?(Regexp) && source == v.source && options == v.options
  alias eql? ==
  def source = Intrinsics.regexp_source(self)
  def options = Intrinsics.regexp_options(self)
  def inspect = Intrinsics.regexp_inspect(self)
  def to_s = Intrinsics.regexp_to_s(self)
  def casefold? = (options & IGNORECASE) != 0
  def fixed_encoding? = (options & FIXEDENCODING) != 0
  def encoding = Intrinsics.regexp_encoding(self)
  def named_captures = Intrinsics.regexp_named_captures(self)
  def names = Intrinsics.regexp_names(self)
  def match?(str, pos = 0) = Intrinsics.regexp_match_bool(self, str, pos)
  def =~(str) = Intrinsics.regexp_match_index(self, str)
  def ~() = Intrinsics.regexp_tilde(self)
  def hash = [source, options].hash
  def linear_time? = Intrinsics.regexp_linear_time_q(self)
  def dup = Regexp.new(source, options)
  def self.escape(str) = Intrinsics.regexp_escape(str)
  def self.quote(str) = Intrinsics.regexp_escape(str)
  def self.union(*patterns) = Intrinsics.regexp_union(patterns)
  def self.last_match(n = nil) = Intrinsics.regexp_last_match(n)
  def self.linear_time?(pattern, flags = nil) = Intrinsics.regexp_class_linear_time_q(pattern, flags)
  def self.new(pattern, options = nil, **kw_opts) = Intrinsics.regexp_new(self, pattern, options, kw_opts)
  def self.compile(pattern, options = nil, **kw_opts) = Intrinsics.regexp_new(self, pattern, options, kw_opts)
  def self.timeout = Intrinsics.regexp_timeout(self)
  def self.timeout=(v) = Intrinsics.regexp_set_timeout(self, v)
  def self.try_convert(obj)
    return obj if obj.is_a?(Regexp)
    return nil unless obj.respond_to?(:to_regexp)
    result = obj.to_regexp
    raise TypeError, "can't convert #{obj.class} into Regexp (#{obj.class}#to_regexp gives #{result.class})" unless result.is_a?(Regexp)
    result
  end

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

  def clone(freeze: nil)
    c = dup
    should_freeze = freeze.nil? ? frozen? : freeze
    raise ArgumentError, "can't unfreeze Regexp" if freeze == false
    c.freeze if should_freeze
    c
  end

  class TimeoutError < RegexpError; end

  private

  def initialize(pattern = nil, options = nil)
    raise FrozenError, "can't modify frozen Regexp: #{inspect}" if frozen?
    raise TypeError, "already initialized regexp" unless Intrinsics.regexp_newly_created_q(self)
  end
end

