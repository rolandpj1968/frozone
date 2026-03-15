class Exception
  def initialize(message = nil)
    @message = message
  end

  def message
    @message || self.class.to_s
  end

  def to_s = message.to_s

  def backtrace = instance_variable_defined?(:@backtrace) ? @backtrace : []
  def backtrace_locations = []

  def set_backtrace(bt)
    if bt.nil?
      @backtrace = nil
    elsif bt.is_a?(String)
      @backtrace = [bt]
    elsif bt.is_a?(Array)
      bt.each { |e| raise TypeError, "backtrace must be an Array of String" unless e.is_a?(String) }
      @backtrace = bt
    else
      raise TypeError, "backtrace must be an Array of String"
    end
    @backtrace
  end

  def self.exception(message = nil) = new(message)

  def exception(message = nil)
    message ? self.class.new(message) : self
  end

  def cause = @cause
end

class ScriptError < Exception; end
class LoadError < ScriptError; end
class SyntaxError < ScriptError; end
class NotImplementedError < ScriptError; end

class SignalException < Exception; end
class Interrupt < SignalException; end

class SystemExit < Exception
  def initialize(status = 0, message = nil)
    if status.is_a?(String)
      @status = 0
      super(status)
    else
      @status = status.is_a?(Integer) ? status : (status ? 0 : 1)
      super(message)
    end
  end

  def status = @status
  def success? = @status == 0
end

class StandardError < Exception; end

class RuntimeError < StandardError; end
class FrozenError < RuntimeError; end

class NameError < StandardError
  def initialize(message = nil, name = nil)
    @name = name
    super(message)
  end

  def name = @name
end

class NoMethodError < NameError
  def initialize(message = nil, name = nil, args = nil)
    @args = args
    super(message, name)
  end

  def args = @args
end

class TypeError < StandardError; end
class ArgumentError < StandardError; end
class RangeError < StandardError; end
class FloatDomainError < RangeError; end
class ZeroDivisionError < StandardError; end
class IndexError < StandardError; end
class KeyError < IndexError; end
class StopIteration < IndexError
  def result = nil
end
class LocalJumpError < StandardError; end
class SystemCallError < StandardError; end
class IOError < StandardError; end
class EOFError < IOError; end
class EncodingError < StandardError; end
class RegexpError < StandardError; end
module Math
  class DomainError < ArgumentError; end

  PI = 3.141592653589793
  E  = 2.718281828459045

  def self.sqrt(x)     = Intrinsics.float_sqrt(x.to_f)
  def self.cbrt(x)     = Intrinsics.float_cbrt(x.to_f)
  def self.exp(x)      = Intrinsics.float_exp(x.to_f)
  def self.log(x, base = nil)
    base ? Intrinsics.float_log(x.to_f) / Intrinsics.float_log(base.to_f) : Intrinsics.float_log(x.to_f)
  end
  def self.log2(x)     = Intrinsics.float_log2(x.to_f)
  def self.log10(x)    = Intrinsics.float_log10(x.to_f)
  def self.sin(x)      = Intrinsics.float_sin(x.to_f)
  def self.cos(x)      = Intrinsics.float_cos(x.to_f)
  def self.tan(x)      = Intrinsics.float_tan(x.to_f)
  def self.asin(x)     = Intrinsics.float_asin(x.to_f)
  def self.acos(x)     = Intrinsics.float_acos(x.to_f)
  def self.atan(x)     = Intrinsics.float_atan(x.to_f)
  def self.atan2(y, x) = Intrinsics.float_atan2(y.to_f, x.to_f)
  def self.sinh(x)     = Intrinsics.float_sinh(x.to_f)
  def self.cosh(x)     = Intrinsics.float_cosh(x.to_f)
  def self.tanh(x)     = Intrinsics.float_tanh(x.to_f)
  def self.asinh(x)    = Intrinsics.float_asinh(x.to_f)
  def self.acosh(x)    = Intrinsics.float_acosh(x.to_f)
  def self.atanh(x)    = Intrinsics.float_atanh(x.to_f)
  def self.hypot(a, b) = Intrinsics.float_hypot(a.to_f, b.to_f)
  def self.frexp(x)    = Intrinsics.float_frexp(x.to_f)
  def self.ldexp(x, n) = Intrinsics.float_ldexp(x.to_f, n.to_i)
end
