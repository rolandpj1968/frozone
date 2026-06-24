class Exception
  def message = to_s
  def backtrace = @backtrace
  def self.exception(message = nil) = message.nil? ? new : new(message)
  def cause = @cause
  def to_s = @message ? @message.to_s : self.class.to_s
  def initialize_copy(other) = super

  def initialize(message = nil)
    @message = message
  end

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

  def exception(message = nil)
    return self if message.nil? || message.equal?(self)
    copy = self.class.allocate
    copy.send(:initialize_copy, self)
    copy.instance_variable_set(:@message, message)
    copy
  end

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
    dm = __full_message_dm__(hl, **kwargs)
    dm = dm.nil? ? (hl ? "\e[1;4m#{self.class.name || self.class.inspect}\e[m" : (self.class.name || self.class.inspect).to_s) : dm.to_str rescue dm.to_s
    bt = backtrace

    result = __format_single_full_message__(bt, dm, hl, actual_order, explicit_bottom: explicit_bottom)

    # Append cause chain
    c = cause
    seen = [self.object_id]
    while c && !seen.include?(c.object_id)
      seen << c.object_id
      c_dm = c.__full_message_dm__(hl, **kwargs) rescue c.class.name.to_s
      c_dm = c_dm.nil? ? c.class.name.to_s : (c_dm.to_str rescue c_dm.to_s)
      c_bt = c.backtrace
      result += __format_single_full_message__(c_bt, c_dm, hl, actual_order, explicit_bottom: explicit_bottom)
      c = c.cause rescue nil
    end

    result
  end

  def __full_message_dm__(hl, **kwargs)
    if respond_to?(:detailed_message)
      detailed_message(highlight: hl, **kwargs)
    else
      hl ? "\e[1;4m#{self.class.name || self.class.inspect}\e[m" : (self.class.name || self.class.inspect).to_s
    end
  end

  private

  def __format_single_full_message__(bt, dm, hl, order, explicit_bottom: false)
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
  def path = @path

  def initialize(message = nil, path: nil)
    super(message)
    @path = path
  end
end

class SyntaxError < ScriptError
  def path = @path

  def initialize(message = nil, path: nil)
    super(message)
    @path = path
  end
end

class NotImplementedError < ScriptError; end

class SignalException < Exception
  def signo = @signo
  def signm = @signm

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
end

class Interrupt < SignalException
  def initialize(message = nil)
    @signo = Signal.list["INT"] || 2
    @signm = message || "Interrupt"
    @message = @signm
  end
end

class SystemExit < Exception
  def status = @status
  def success? = @status == 0

  def initialize(code = true, msg = nil)
    if code.is_a?(String)
      @status = 0
      super(code)
    else
      @status = code.is_a?(Integer) ? code : (code ? 0 : 1)
      super(msg || self.class.name)
    end
  end
end

class StandardError < Exception; end

class RuntimeError < StandardError; end

class FrozenError < RuntimeError
  def receiver = @receiver

  def initialize(message = nil, receiver: nil)
    super(message)
    @receiver = receiver
  end
end

class NameError < StandardError
  def name = @name

  def initialize(message = nil, name = nil, receiver: :__no_receiver__)
    @name = name
    @receiver = receiver unless receiver.equal?(:__no_receiver__)
    super(message)
  end

  def receiver
    raise ArgumentError, "no receiver is available" unless instance_variable_defined?(:@receiver)
    @receiver
  end
end

class NoMethodError < NameError
  def args = @args || []

  def initialize(message = nil, name = nil, args = nil, receiver: :__no_receiver__)
    @args = args.nil? ? [] : args
    super(message, name, receiver: receiver)
  end
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
class NoMatchingPatternError < StandardError; end
class KeyError < IndexError
  def receiver = @receiver
  def key = @key

  def initialize(message = nil, receiver: nil, key: nil)
    super(message)
    @receiver = receiver
    @key = key
  end
end
class StopIteration < IndexError
  def result = @result
end
class ClosedQueueError < StopIteration; end
class UncaughtThrowError < ArgumentError
  attr_reader :tag, :value
  def initialize(tag = nil, value = nil, message = nil)
    super(message || "uncaught throw #{tag.inspect}")
    @tag = tag
    @value = value
  end
end
class LocalJumpError < StandardError
  def exit_value = @exit_value
  def reason = @reason

  def initialize(message = nil, exit_value: nil, reason: :return)
    super(message)
    @exit_value = exit_value
    @reason = reason
  end
end
class SystemCallError < StandardError
  def errno = @errno

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
end
class IOError < StandardError; end
class EOFError < IOError; end
class EncodingError < StandardError; end
class RegexpError < StandardError; end
