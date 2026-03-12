class Exception
  def initialize(message = nil)
    @message = message
  end

  def message
    @message || self.class.to_s
  end

  def to_s = message.to_s

  def backtrace = []
  def backtrace_locations = []

  def self.exception(message = nil) = new(message)

  def exception(message = nil)
    message ? self.class.new(message) : self
  end
end

class ScriptError < Exception; end
class LoadError < ScriptError; end
class SyntaxError < ScriptError; end
class NotImplementedError < ScriptError; end

class SignalException < Exception; end
class Interrupt < SignalException; end

class SystemExit < Exception
  def initialize(status = 0, message = nil)
    @status = status
    super(message)
  end

  def status = @status
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
end
