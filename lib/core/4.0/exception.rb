class Exception
  def initialize(message = nil)
    @message = message
  end

  def to_s
    @message ? @message.to_s : self.class.to_s
  end

  def message = to_s

  def backtrace = @backtrace

  def backtrace_locations
    return nil unless @_has_locations
    return nil if @backtrace.nil?
    @backtrace_locations ||= @backtrace.map { |s| Thread::Backtrace::Location._from_string(s.to_s) }
  end

  def set_backtrace(bt)
    if bt.nil?
      @backtrace = nil
      @_has_locations = false
      @backtrace_locations = nil
    elsif bt.is_a?(String)
      @backtrace = [bt]
      @_has_locations = false
      @backtrace_locations = nil
    elsif bt.is_a?(Array)
      if !bt.empty? && bt.first.is_a?(Thread::Backtrace::Location)
        @backtrace_locations = bt.dup
        @backtrace = bt.map(&:to_s)
        @_has_locations = true
      else
        bt.each { |e| raise TypeError, "backtrace must be an Array of String" unless e.is_a?(String) }
        @backtrace = bt
        @_has_locations = false
        @backtrace_locations = nil
      end
    else
      raise TypeError, "backtrace must be an Array of String"
    end
    @backtrace
  end

  def self.exception(message = nil) = message.nil? ? new : new(message)

  def exception(message = nil)
    return self if message.nil? || message.equal?(self)
    copy = self.class.allocate
    copy.send(:initialize_copy, self)
    copy.instance_variable_set(:@message, message)
    copy
  end

  def initialize_copy(other)
    super
  end

  def cause = @cause

  def ==(other)
    return true if equal?(other)
    return false unless other.is_a?(Exception)
    return false unless other.class == self.class
    return false unless other.message == message
    return false unless other.backtrace == backtrace
    true
  end

  def inspect
    msg = to_s
    if msg.nil? || msg.empty?
      self.class.name || self.class.to_s
    else
      "#<#{self.class.name || self.class.to_s}: #{msg}>"
    end
  end

  def detailed_message(highlight: nil, **_opts)
    class_name = self.class.name
    msg = message.to_s
    empty_msg = msg.nil? || msg.empty?

    if highlight
      if empty_msg
        if is_a?(RuntimeError) && !class_name
          "\e[1;4m#{self.class.inspect}\e[m"
        elsif class_name == "RuntimeError"
          "\e[1;4munhandled exception\e[m"
        else
          "\e[1;4m#{class_name || self.class.inspect}\e[m"
        end
      elsif class_name
        lines = msg.split("\n", -1)
        if lines.length > 1
          first = "\e[1m#{lines[0]} (\e[1;4m#{class_name}\e[m\e[1m)\e[m"
          rest = lines[1..].map { |l| "\e[1m#{l}\e[m" }.join("\n")
          "#{first}\n#{rest}"
        else
          "\e[1m#{msg} (\e[1;4m#{class_name}\e[m\e[1m)\e[m"
        end
      else
        lines = msg.split("\n", -1)
        lines.map { |l| "\e[1m#{l}\e[m" }.join("\n")
      end
    else
      if empty_msg
        if is_a?(RuntimeError) && !class_name
          self.class.inspect
        elsif class_name == "RuntimeError"
          "unhandled exception"
        else
          class_name || self.class.inspect
        end
      elsif class_name
        lines = msg.split("\n", -1)
        if lines.length > 1
          "#{lines[0]} (#{class_name})\n#{lines[1..].join("\n")}"
        else
          "#{msg} (#{class_name})"
        end
      else
        msg
      end
    end
  end

  def self.to_tty?
    Intrinsics.exception_tty_check
  end

  ORDER_UNSET = :__order_unset__
  private_constant :ORDER_UNSET

  def full_message(highlight: nil, order: ORDER_UNSET, **kwargs)
    hl = highlight.nil? ? Exception.to_tty? : highlight
    # When order is not explicitly passed, MRI uses single-line format (like :top).
    # When order: :bottom is explicitly passed, MRI prepends the Traceback header.
    explicit_bottom = (order == :bottom)
    actual_order = (order == ORDER_UNSET) ? :top : order

    # Get the detailed message, calling #detailed_message with all kwargs + highlight
    dm = _full_message_dm(hl, **kwargs)
    dm = dm.nil? ? (hl ? "\e[1;4m#{self.class.name || self.class.inspect}\e[m" : (self.class.name || self.class.inspect).to_s) : dm.to_str rescue dm.to_s
    bt = backtrace

    result = _format_single_full_message(bt, dm, hl, actual_order, explicit_bottom: explicit_bottom)

    # Append cause chain
    c = cause
    seen = [self.object_id]
    while c && !seen.include?(c.object_id)
      seen << c.object_id
      c_dm = c._full_message_dm(hl, **kwargs) rescue c.class.name.to_s
      c_dm = c_dm.nil? ? c.class.name.to_s : (c_dm.to_str rescue c_dm.to_s)
      c_bt = c.backtrace
      result += _format_single_full_message(c_bt, c_dm, hl, actual_order, explicit_bottom: explicit_bottom)
      c = c.cause rescue nil
    end

    result
  end

  def _full_message_dm(hl, **kwargs)
    if respond_to?(:detailed_message)
      detailed_message(highlight: hl, **kwargs)
    else
      hl ? "\e[1;4m#{self.class.name || self.class.inspect}\e[m" : (self.class.name || self.class.inspect).to_s
    end
  end

  private

  def _format_single_full_message(bt, dm, hl, order, explicit_bottom: false)
    if bt.nil? || bt.empty?
      caller_str = Intrinsics.exception_caller_string
      loc = caller_str || "(unknown)"
      if explicit_bottom
        tb_hdr = hl ? "\e[1mTraceback\e[m (most recent call last):\n" : "Traceback (most recent call last):\n"
        return "#{tb_hdr}#{loc}: #{dm}\n"
      else
        return "#{loc}: #{dm}\n"
      end
    end

    if order == :bottom
      tb_hdr = hl ? "\e[1mTraceback\e[m (most recent call last):\n" : "Traceback (most recent call last):\n"
      from_lines = bt[1..].map { |l| "\tfrom #{l}\n" }.join
      tb_hdr + from_lines + "#{bt[0]}: #{dm}\n"
    else
      rest = bt[1..].map { |l| "\tfrom #{l}\n" }.join
      "#{bt[0]}: #{dm}\n" + rest
    end
  end
end

class ScriptError < Exception; end

class LoadError < ScriptError
  def initialize(message = nil, path: nil)
    super(message)
    @path = path
  end

  def path = @path
end

class SyntaxError < ScriptError
  def initialize(message = nil, path: nil)
    super(message)
    @path = path
  end

  def path = @path
end

class NotImplementedError < ScriptError; end

module Signal
  # Standard POSIX signals
  LIST = {
    "HUP"  => 1,  "INT"  => 2,  "QUIT" => 3,  "ILL"  => 4,
    "TRAP" => 5,  "ABRT" => 6,  "BUS"  => 7,  "FPE"  => 8,
    "KILL" => 9,  "USR1" => 10, "SEGV" => 11, "USR2" => 12,
    "PIPE" => 13, "ALRM" => 14, "TERM" => 15, "CHLD" => 17,
    "CONT" => 18, "STOP" => 19, "TSTP" => 20, "TTIN" => 21,
    "TTOU" => 22, "URG"  => 23, "XCPU" => 24, "XFSZ" => 25,
    "VTALRM" => 26, "PROF" => 27, "WINCH" => 28, "IO" => 29,
    "PWR" => 30,  "SYS"  => 31,
  }.freeze

  def self.list = LIST

  def self.trap(signal, command = :__no_command__, &block)
    callable = command.equal?(:__no_command__) ? block : command
    Intrinsics.signal_trap(signal, callable)
  end
end

class SignalException < Exception
  def initialize(sig, message = nil)
    if sig.is_a?(Integer)
      @signo = sig
      entry = Signal.list.find { |_k, v| v == sig }
      raise ArgumentError, "invalid signal number (#{sig})" unless entry
      @signm = message || "SIG#{entry[0]}"
    elsif sig.is_a?(String) || sig.is_a?(Symbol)
      sigstr = sig.to_s.upcase
      if sigstr.start_with?("SIG")
        signame = sigstr[3..]
      else
        signame = sigstr
      end
      unless message.nil?
        raise ArgumentError, "wrong number of arguments (given 2, expected 1)"
      end
      @signo = Signal.list[signame]
      raise ArgumentError, "invalid signal name (#{sig})" unless @signo
      @signm = "SIG#{signame}"
    else
      raise ArgumentError, "bad signal type #{sig.class}"
    end
    super(message || @signm)
  end

  def signo = @signo
  def signm = @signm
end

class Interrupt < SignalException
  def initialize(message = nil)
    @signo = Signal.list["INT"] || 2
    @signm = message || "Interrupt"
    @message = @signm
  end
end

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

class FrozenError < RuntimeError
  def initialize(message = nil, receiver: nil)
    super(message)
    @receiver = receiver
  end

  def receiver = @receiver
end

class NameError < StandardError
  def initialize(message = nil, name = nil, receiver: :__no_receiver__)
    @name = name
    @receiver = receiver unless receiver.equal?(:__no_receiver__)
    super(message)
  end

  def name = @name

  def receiver
    raise ArgumentError, "no receiver is available" unless instance_variable_defined?(:@receiver)
    @receiver
  end
end

class NoMethodError < NameError
  def initialize(message = nil, name = nil, args = nil, receiver: :__no_receiver__)
    @args = args.nil? ? [] : args
    super(message, name, receiver: receiver)
  end

  def args = @args || []
end

class TypeError < StandardError; end
class ArgumentError < StandardError; end
class RangeError < StandardError; end
class FloatDomainError < RangeError; end
class ZeroDivisionError < StandardError; end
class IndexError < StandardError; end
class FiberError < StandardError; end
class ThreadError < StandardError; end
class NoMemoryError < Exception; end
class SecurityError < Exception; end
class SystemStackError < Exception; end
class KeyError < IndexError
  def initialize(message = nil, receiver: nil, key: nil)
    super(message)
    @receiver = receiver
    @key = key
  end

  def receiver = @receiver
  def key = @key
end
class StopIteration < IndexError
  def result = @result
end
class ClosedQueueError < StopIteration; end
class UncaughtThrowError < ArgumentError
  def tag = @tag
end
class LocalJumpError < StandardError
  def initialize(message = nil, exit_value: nil, reason: :return)
    super(message)
    @exit_value = exit_value
    @reason = reason
  end

  def exit_value = @exit_value
  def reason = @reason
end
class SystemCallError < StandardError
  def self.new(message = :__no_arg__, second = nil, third = nil)
    # Non-SystemCallError subclasses: build the instance
    unless equal?(SystemCallError)
      message = nil if message.equal?(:__no_arg__)
      obj = allocate
      # If subclass has custom initialize, call with original user args; otherwise use standard 3-arg form
      if instance_method(:initialize).owner.equal?(SystemCallError)
        obj.send(:initialize, message, nil, second)  # message, errno=nil(from class), location=second
      elsif message.nil? && second.nil? && third.nil?
        obj.send(:initialize)
      elsif second.nil? && third.nil?
        obj.send(:initialize, message)
      elsif third.nil?
        obj.send(:initialize, message, second)
      else
        obj.send(:initialize, message, second, third)
      end
      return obj
    end

    raise ArgumentError, "wrong number of arguments (given 0, expected 1+)" if message.equal?(:__no_arg__)

    # SystemCallError.new factory
    # If first arg is Integer/Float, treat as errno (no message)
    if message.is_a?(Integer)
      errno_val = message; message = nil
    elsif message.is_a?(Float) && second.nil?
      errno_val = message.to_i; message = nil
    elsif !message.nil? && !message.is_a?(String)
      raise TypeError, "no implicit conversion of #{message.class} into String"
    else
      errno_val = second
    end

    location = third

    # Normalize errno_val
    if errno_val.is_a?(Float)
      errno_val = errno_val.to_i
    elsif errno_val.is_a?(Complex)
      begin
        errno_val = Integer(errno_val)
      rescue RangeError
        raise RangeError, "can't convert #{errno_val} into an exact number"
      end
    elsif !errno_val.nil? && !errno_val.is_a?(Integer)
      raise TypeError, "no implicit conversion of #{errno_val.class} into Integer"
    end

    target_class = errno_val ? (Errno._by_errno(errno_val) || SystemCallError) : SystemCallError
    obj = target_class.allocate
    obj.send(:initialize, message, errno_val, location)
    obj
  end

  def initialize(message = nil, errno_val = nil, location = nil)
    @errno = errno_val.nil? ? (self.class::Errno rescue nil) : errno_val
    base = (self.class::Strerror rescue nil) || (@errno ? "Unknown error #{@errno}" : nil)
    loc_str = location ? location.to_s : nil
    if message && loc_str
      super(base ? "#{base} @ #{loc_str} - #{message}" : "@ #{loc_str} - #{message}")
    elsif message
      super(base ? "#{base} - #{message}" : message)
    else
      super(base)
    end
  end

  def errno = @errno
end
class IOError < StandardError; end
class EOFError < IOError; end
class EncodingError < StandardError; end
class RegexpError < StandardError; end

module Errno
  @by_errno = {}

  def self._by_errno(num) = @by_errno[num]

  def self._define(name, num, strerror)
    if @by_errno.key?(num)
      const_set(name, @by_errno[num])
    else
      klass = Class.new(SystemCallError)
      klass.const_set(:Errno, num)
      klass.const_set(:Strerror, strerror)
      @by_errno[num] = klass
      const_set(name, klass)
    end
  end

  _define :E2BIG,          7,  "Argument list too long"
  _define :EACCES,        13,  "Permission denied"
  _define :EADDRINUSE,    98,  "Address already in use"
  _define :EADDRNOTAVAIL, 99,  "Cannot assign requested address"
  _define :EAFNOSUPPORT, 97,   "Address family not supported by protocol"
  _define :EAGAIN,        11,  "Resource temporarily unavailable"
  _define :EALREADY,     114,  "Operation already in progress"
  _define :EBADF,          9,  "Bad file descriptor"
  _define :EBUSY,         16,  "Device or resource busy"
  _define :ECHILD,        10,  "No child processes"
  _define :ECONNABORTED, 103,  "Software caused connection abort"
  _define :ECONNREFUSED, 111,  "Connection refused"
  _define :ECONNRESET,   104,  "Connection reset by peer"
  _define :EDEADLK,       35,  "Resource deadlock avoided"
  _define :EDOM,          33,  "Numerical argument out of domain"
  _define :EEXIST,        17,  "File exists"
  _define :EFAULT,        14,  "Bad address"
  _define :EFBIG,         27,  "File too large"
  _define :EHOSTUNREACH,  113, "No route to host"
  _define :EINPROGRESS,  115,  "Operation now in progress"
  _define :EINTR,          4,  "Interrupted system call"
  _define :EINVAL,        22,  "Invalid argument"
  _define :EIO,            5,  "Input/output error"
  _define :EISCONN,       106, "Transport endpoint is already connected"
  _define :EISDIR,        21,  "Is a directory"
  _define :ELOOP,         40,  "Too many levels of symbolic links"
  _define :EMFILE,        24,  "Too many open files"
  _define :EMSGSIZE,      90,  "Message too long"
  _define :ENAMETOOLONG,  36,  "File name too long"
  _define :ENETDOWN,     100,  "Network is down"
  _define :ENETUNREACH,  101,  "Network is unreachable"
  _define :ENFILE,        23,  "Too many open files in system"
  _define :ENODEV,        19,  "No such device"
  _define :ENOENT,         2,  "No such file or directory"
  _define :ENOEXEC,        8,  "Exec format error"
  _define :ENOMEM,        12,  "Cannot allocate memory"
  _define :ENOSPC,        28,  "No space left on device"
  _define :ENOSYS,        38,  "Function not implemented"
  _define :ENOTCONN,     107,  "Transport endpoint is not connected"
  _define :ENOTDIR,       20,  "Not a directory"
  _define :ENOTEMPTY,     39,  "Directory not empty"
  _define :ENOTSUP,       95,  "Operation not supported"
  _define :ENOTTY,        25,  "Inappropriate ioctl for device"
  _define :ENXIO,          6,  "No such device or address"
  _define :EOPNOTSUPP,    95,  "Operation not supported"
  _define :EOVERFLOW,     75,  "Value too large for defined data type"
  _define :EPERM,          1,  "Operation not permitted"
  _define :EPIPE,         32,  "Broken pipe"
  _define :EPROTONOSUPPORT, 93,"Protocol not supported"
  _define :ERANGE,        34,  "Numerical result out of range"
  _define :EROFS,         30,  "Read-only file system"
  _define :ESPIPE,        29,  "Illegal seek"
  _define :ESRCH,          3,  "No such process"
  _define :ETIMEDOUT,    110,  "Connection timed out"
  _define :ETXTBSY,       26,  "Text file busy"
  _define :EWOULDBLOCK,   11,  "Resource temporarily unavailable"
  _define :EXDEV,         18,  "Invalid cross-device link"
end

module Math
  class DomainError < ArgumentError; end

  PI = 3.141592653589793
  E  = 2.718281828459045

  def self._coerce_float(x, func)
    return x if x.is_a?(Float)
    return x.to_f if x.is_a?(Integer)
    type_name = x.nil? ? "nil" : x.class.to_s
    raise TypeError, "can't convert #{type_name} into Float" unless x.is_a?(Numeric)
    result = x.to_f
    raise TypeError, "can't convert #{type_name} into Float" unless result.is_a?(Float)
    result
  end
  private_class_method :_coerce_float

  def self._coerce_integer(n)
    return n if n.is_a?(Integer)
    type_name = n.nil? ? "nil" : n.class.to_s
    raise TypeError, "can't convert #{type_name} into Integer" unless n.respond_to?(:to_int)
    result = n.to_int
    raise TypeError, "can't convert #{type_name} into Integer" unless result.is_a?(Integer)
    result
  end
  private_class_method :_coerce_integer

  def self.sqrt(x)     = Intrinsics.float_sqrt(_coerce_float(x, :sqrt))
  def self.cbrt(x)     = Intrinsics.float_cbrt(_coerce_float(x, :cbrt))
  def self.exp(x)      = Intrinsics.float_exp(_coerce_float(x, :exp))

  def self.log(x, base = :__no_base__)
    xf = _coerce_float(x, :log)
    base.equal?(:__no_base__) ? Intrinsics.float_log(xf) : Intrinsics.float_log(xf) / Intrinsics.float_log(_coerce_float(base, :log))
  end

  def self.log2(x)
    if x.is_a?(Integer) && x > 0
      xf = x.to_f
      if xf.infinite?
        bl = x.bit_length
        mantissa = (x >> (bl - 54)).to_f / (1 << 53).to_f
        return Intrinsics.float_log2(mantissa) + (bl - 1)
      end
      return Intrinsics.float_log2(xf)
    end
    Intrinsics.float_log2(_coerce_float(x, :log2))
  end

  def self.log10(x)    = Intrinsics.float_log10(_coerce_float(x, :log10))
  def self.sin(x)      = Intrinsics.float_sin(_coerce_float(x, :sin))
  def self.cos(x)      = Intrinsics.float_cos(_coerce_float(x, :cos))
  def self.tan(x)      = Intrinsics.float_tan(_coerce_float(x, :tan))
  def self.asin(x)     = Intrinsics.float_asin(_coerce_float(x, :asin))
  def self.acos(x)     = Intrinsics.float_acos(_coerce_float(x, :acos))
  def self.atan(x)     = Intrinsics.float_atan(_coerce_float(x, :atan))
  def self.atan2(y, x) = Intrinsics.float_atan2(_coerce_float(y, :atan2), _coerce_float(x, :atan2))
  def self.sinh(x)     = Intrinsics.float_sinh(_coerce_float(x, :sinh))
  def self.cosh(x)     = Intrinsics.float_cosh(_coerce_float(x, :cosh))
  def self.tanh(x)     = Intrinsics.float_tanh(_coerce_float(x, :tanh))
  def self.asinh(x)    = Intrinsics.float_asinh(_coerce_float(x, :asinh))
  def self.acosh(x)    = Intrinsics.float_acosh(_coerce_float(x, :acosh))
  def self.atanh(x)    = Intrinsics.float_atanh(_coerce_float(x, :atanh))
  def self.hypot(a, b) = Intrinsics.float_hypot(_coerce_float(a, :hypot), _coerce_float(b, :hypot))
  def self.frexp(x)    = Intrinsics.float_frexp(_coerce_float(x, :frexp))
  def self.ldexp(x, n)
    xf = _coerce_float(x, :ldexp)
    ni = if n.is_a?(Float)
      raise RangeError, "float NaN out of range of integer" if n.nan?
      n.to_i
    else
      _coerce_integer(n)
    end
    Intrinsics.float_ldexp(xf, ni)
  end
  def self.erf(x)      = Intrinsics.float_erf(_coerce_float(x, :erf))
  def self.erfc(x)     = Intrinsics.float_erfc(_coerce_float(x, :erfc))
  def self.expm1(x)    = Intrinsics.float_expm1(_coerce_float(x, :expm1))
  def self.log1p(x)    = Intrinsics.float_log1p(_coerce_float(x, :log1p))
  def self.gamma(x)    = Intrinsics.float_gamma(_coerce_float(x, :gamma))
  def self.lgamma(x)   = Intrinsics.float_lgamma(_coerce_float(x, :lgamma))

  # Also define instance methods for when Math is included
  def sqrt(x)     = Math.sqrt(x)
  def cbrt(x)     = Math.cbrt(x)
  def exp(x)      = Math.exp(x)
  def log(x, base = nil) = Math.log(x, *[base].compact)
  def log2(x)     = Math.log2(x)
  def log10(x)    = Math.log10(x)
  def log1p(x)    = Math.log1p(x)
  def sin(x)      = Math.sin(x)
  def cos(x)      = Math.cos(x)
  def tan(x)      = Math.tan(x)
  def asin(x)     = Math.asin(x)
  def acos(x)     = Math.acos(x)
  def atan(x)     = Math.atan(x)
  def atan2(y, x) = Math.atan2(y, x)
  def sinh(x)     = Math.sinh(x)
  def cosh(x)     = Math.cosh(x)
  def tanh(x)     = Math.tanh(x)
  def asinh(x)    = Math.asinh(x)
  def acosh(x)    = Math.acosh(x)
  def atanh(x)    = Math.atanh(x)
  def hypot(a, b) = Math.hypot(a, b)
  def frexp(x)    = Math.frexp(x)
  def ldexp(x, n) = Math.ldexp(x, n)
  def erf(x)      = Math.erf(x)
  def erfc(x)     = Math.erfc(x)
  def expm1(x)    = Math.expm1(x)
  def gamma(x)    = Math.gamma(x)
  def lgamma(x)   = Math.lgamma(x)
  private :sqrt, :cbrt, :exp, :log, :log2, :log10, :log1p, :sin, :cos, :tan,
          :asin, :acos, :atan, :atan2, :sinh, :cosh, :tanh, :asinh, :acosh, :atanh,
          :hypot, :frexp, :ldexp, :erf, :erfc, :expm1, :gamma, :lgamma
end

class SystemExit < Exception
  def initialize(code = true, msg = nil)
    if code.is_a?(String)
      @status = 0
      super(code)
    else
      @status = code.is_a?(Integer) ? code : (code ? 0 : 1)
      super(msg || self.class.name)
    end
  end

  def status   = @status
  def success? = @status == 0
end

class FrozenError
  def receiver = @receiver
end

class Thread
  class Backtrace
    class Location
      def self._from_string(str)
        loc = allocate
        m = str.match(/\A(.*):(\d+):in '(.*)'\z/)
        if m
          loc.instance_variable_set(:@path, m[1])
          loc.instance_variable_set(:@lineno, m[2].to_i)
          loc.instance_variable_set(:@label, m[3])
        else
          m2 = str.match(/\A(.*):(\d+)\z/)
          if m2
            loc.instance_variable_set(:@path, m2[1])
            loc.instance_variable_set(:@lineno, m2[2].to_i)
            loc.instance_variable_set(:@label, nil)
          else
            loc.instance_variable_set(:@path, str)
            loc.instance_variable_set(:@lineno, 0)
            loc.instance_variable_set(:@label, nil)
          end
        end
        loc
      end

      def path = @path
      def lineno = @lineno
      def label = @label || "<main>"

      def base_label
        (@label || "<main>").sub(/\Ablock( \(\d+\))? in /, "")
      end

      def absolute_path
        return nil unless @path
        File.expand_path(@path)
      end

      def to_s
        @label ? "#{@path}:#{@lineno}:in '#{@label}'" : "#{@path}:#{@lineno}"
      end

      def inspect = to_s
    end
  end
end
