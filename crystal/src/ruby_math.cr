# RubyMath — Crystal wrapper for Ruby's Math module.
# Delegates to Crystal's built-in Math, wrapping results as RubyFloat.

module RubyMath
  def self.sqrt(x : RubyObject) : RubyFloat
    v = x.is_a?(RubyFloat) ? x.to_f64 : x.is_a?(RubyInteger) ? x.to_i64.to_f64 : 0.0_f64
    RubyFloat.new(Math.sqrt(v))
  end

  def self.sin(x : RubyObject) : RubyFloat
    v = x.is_a?(RubyFloat) ? x.to_f64 : x.is_a?(RubyInteger) ? x.to_i64.to_f64 : 0.0_f64
    RubyFloat.new(Math.sin(v))
  end

  def self.cos(x : RubyObject) : RubyFloat
    v = x.is_a?(RubyFloat) ? x.to_f64 : x.is_a?(RubyInteger) ? x.to_i64.to_f64 : 0.0_f64
    RubyFloat.new(Math.cos(v))
  end

  def self.log(x : RubyObject) : RubyFloat
    v = x.is_a?(RubyFloat) ? x.to_f64 : x.is_a?(RubyInteger) ? x.to_i64.to_f64 : 0.0_f64
    RubyFloat.new(Math.log(v))
  end

  def self.log2(x : RubyObject) : RubyFloat
    v = x.is_a?(RubyFloat) ? x.to_f64 : x.is_a?(RubyInteger) ? x.to_i64.to_f64 : 0.0_f64
    RubyFloat.new(Math.log2(v))
  end

  def self.log10(x : RubyObject) : RubyFloat
    v = x.is_a?(RubyFloat) ? x.to_f64 : x.is_a?(RubyInteger) ? x.to_i64.to_f64 : 0.0_f64
    RubyFloat.new(Math.log10(v))
  end

  def self.exp(x : RubyObject) : RubyFloat
    v = x.is_a?(RubyFloat) ? x.to_f64 : x.is_a?(RubyInteger) ? x.to_i64.to_f64 : 0.0_f64
    RubyFloat.new(Math.exp(v))
  end

  PI = RubyFloat.new(Math::PI)
end
