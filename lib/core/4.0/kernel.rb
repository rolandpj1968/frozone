module Kernel
  def puts(*args) = Intrinsics.kernel_puts(self, args)
  def print(*args) = Intrinsics.kernel_print(self, args)
  def warn(*args, category: nil, uplevel: nil)
    return nil if $VERBOSE.nil?
    return nil if args.empty?
    if !category.nil?
      if category.is_a?(Symbol)
        # ok
      elsif category.respond_to?(:to_sym)
        category = category.to_sym
      else
        raise TypeError, "no implicit conversion of #{category.class} into Symbol"
      end
      return nil if !Warning[category]
    end
    prefix = if uplevel.nil?
      nil
    else
      unless uplevel.is_a?(Integer)
        if uplevel.respond_to?(:to_int)
          uplevel = uplevel.to_int
          raise TypeError, "no implicit conversion into Integer" unless uplevel.is_a?(Integer)
        else
          raise TypeError, "no implicit conversion of #{uplevel.class} into Integer"
        end
      end
      raise ArgumentError, "negative level (#{uplevel})" if uplevel < 0
      locs = caller_locations(uplevel + 1, 1)
      loc = locs&.first
      loc ? "#{loc.path}:#{loc.lineno}: warning: " : "warning: "
    end
    emit = ->(str) {
      str = "#{prefix}#{str}" if prefix
      str += "\n" unless str.end_with?("\n")
      begin; Warning.warn(str, category: category); rescue ArgumentError; Warning.warn(str); end
    }
    args.each do |msg|
      if msg.is_a?(Array)
        msg.each { |m| emit.(m.to_s) }
      else
        emit.(msg.to_s)
      end
    end
    nil
  end
  def p(*args) = Intrinsics.kernel_p(self, args)
  def raise(msg = :__raise_no_arg__, message = nil, backtrace = nil, **kwargs)
    cause = kwargs.key?(:cause) ? kwargs.delete(:cause) : :__raise_no_cause__
    message = kwargs if message.nil? && !kwargs.empty?
    Intrinsics.kernel_raise(self, msg, message, backtrace, cause)
  end

  def fail(msg = :__raise_no_arg__, message = nil, backtrace = nil, **kwargs)
    cause = kwargs.key?(:cause) ? kwargs.delete(:cause) : :__raise_no_cause__
    message = kwargs if message.nil? && !kwargs.empty?
    Intrinsics.kernel_raise(self, msg, message, backtrace, cause)
  end

  def require(path)
    path = __coerce_load_path__(path)
    Intrinsics.kernel_require(self, path)
  end

  def require_relative(path)
    path = __coerce_load_path__(path)
    Intrinsics.kernel_require_relative(self, path)
  end

  def load(path, wrap = false)
    path = __coerce_load_path__(path)
    Intrinsics.kernel_load(self, path, wrap)
  end

  def __coerce_load_path__(path)
    if path.is_a?(String)
      path
    elsif path.nil?
      raise TypeError, "no implicit conversion of nil into String"
    elsif path.is_a?(Integer)
      raise TypeError, "no implicit conversion of Integer into String"
    elsif path.respond_to?(:to_path)
      p = path.to_path
      unless p.is_a?(String)
        if p.respond_to?(:to_str)
          p = p.to_str
          raise TypeError, "no implicit conversion of #{path.class} into String" unless p.is_a?(String)
        else
          raise TypeError, "no implicit conversion of #{path.class} into String"
        end
      end
      p
    elsif path.respond_to?(:to_str)
      p = path.to_str
      raise TypeError, "no implicit conversion of #{path.class} into String" unless p.is_a?(String)
      p
    else
      raise TypeError, "no implicit conversion of #{path.class} into String"
    end
  end
  private :__coerce_load_path__
  def __dir__ = Intrinsics.kernel_dir(self)

  def proc(&_block) = Intrinsics.kernel_proc(self)
  def lambda(&_block) = Intrinsics.kernel_lambda(self)

  def eval(code, binding = nil, file = nil, line = nil) = Intrinsics.kernel_eval(self, code, binding, file, line)
  def binding = Intrinsics.kernel_binding(self)

  def sprintf(fmt, *args)
    fmt = fmt.to_str if !fmt.is_a?(String) && fmt.respond_to?(:to_str)
    raise TypeError, "no implicit conversion of #{fmt.class} into String" unless fmt.is_a?(String)
    fmt % args
  end

  def format(fmt, *args) = sprintf(fmt, *args)

  def printf(*args)
    if !args.empty? && !args.first.is_a?(String)
      io = args.shift
      io.write(sprintf(*args))
    else
      $stdout.write(sprintf(*args))
    end
    nil
  end

  def Integer(val, *base_args, exception: true)
    no_base = base_args.empty?
    raw_base = no_base ? 0 : base_args[0]

    # Coerce base to integer
    base = if raw_base.is_a?(Integer)
      raw_base
    elsif raw_base.respond_to?(:to_int)
      raw_base.to_int
    else
      return nil unless exception
      raise TypeError, "no implicit conversion of #{raw_base.class} into Integer"
    end

    if val.is_a?(Integer)
      unless no_base || base == 0
        return nil unless exception
        raise ArgumentError, "wrong number of arguments (given 2, expected 1)"
      end
      return val
    elsif val.is_a?(Float)
      unless no_base || base == 0
        return nil unless exception
        raise ArgumentError, "wrong number of arguments (given 2, expected 1)"
      end
      if val.infinite? || val.nan?
        return nil unless exception
        raise FloatDomainError, val.to_s
      end
      return val.to_i
    elsif val.is_a?(String)
      return Intrinsics.kernel_integer(self, val, base, exception)
    elsif val.nil?
      return nil unless exception
      raise TypeError, "can't convert nil into Integer"
    else
      unless no_base || base == 0
        return nil unless exception
        raise ArgumentError, "wrong number of arguments (given 2, expected 1)"
      end
      # Try to_int first; if it returns non-Integer, fall through to to_i
      to_int_result = nil
      if val.respond_to?(:to_int)
        to_int_result = val.to_int
        return to_int_result if to_int_result.is_a?(Integer)
        # to_int returned nil or non-Integer: fall through to to_i
      end
      # Try to_i
      if val.respond_to?(:to_i)
        result = val.to_i
        if result.is_a?(Integer)
          return result
        elsif result.nil?
          return nil unless exception
          raise TypeError, "can't convert #{val.class} into Integer"
        else
          return nil unless exception
          raise TypeError, "can't convert #{val.class} into Integer (#{val.class}#to_i gives #{result.class})"
        end
      end
      # to_int returned non-Integer and no to_i — raise TypeError about to_int
      if !to_int_result.nil? && val.respond_to?(:to_int)
        return nil unless exception
        raise TypeError, "can't convert #{val.class} into Integer (#{val.class}#to_int gives #{to_int_result.class})"
      end
      return nil unless exception
      raise TypeError, "can't convert #{val.class} into Integer"
    end
  end
  def Float(val, exception: true)
    if val.is_a?(Float)
      return val
    elsif val.is_a?(Integer)
      return val.to_f
    elsif val.is_a?(Rational)
      return val.to_f
    elsif val.is_a?(Complex)
      if val.imaginary == 0
        return val.real.to_f
      else
        return nil unless exception
        raise RangeError, "can't convert #{val.inspect} into Float"
      end
    elsif val.is_a?(String)
      begin
        return Intrinsics.kernel_float(self, val)
      rescue TypeError, ArgumentError
        return nil unless exception
        raise
      end
    elsif val.nil?
      return nil unless exception
      raise TypeError, "can't convert nil into Float"
    else
      if val.respond_to?(:to_f)
        begin
          f = val.to_f
        rescue
          return nil unless exception
          raise TypeError, "can't convert #{val.class} into Float"
        end
        unless f.is_a?(Float)
          return nil unless exception
          raise TypeError, "can't convert #{val.class} into Float (#{val.class}#to_f gives #{f.class})"
        end
        return f
      end
      return nil unless exception
      raise TypeError, "can't convert #{val.class} into Float"
    end
  end
  def String(val)
    return val if val.is_a?(String)
    if val.respond_to?(:to_str)
      result = val.to_str
      return result if result.is_a?(String)
    end
    # MRI checks respond_to?(:to_s) only when to_s is actually defined (not undef'd).
    # When undef'd, MRI calls to_s directly (may go through method_missing).
    # Objects that can't have singleton classes (e.g. Integer, Float) always have to_s defined.
    to_s_defined = begin
      val.singleton_class.method_defined?(:to_s)
    rescue TypeError
      true
    end
    if to_s_defined
      raise TypeError, "no implicit conversion of #{val.class} into String" unless val.respond_to?(:to_s)
    end
    begin
      result = val.to_s
      raise TypeError, "no implicit conversion of #{val.class} into String" unless result.is_a?(String)
      result
    rescue NoMethodError
      raise TypeError, "no implicit conversion of #{val.class} into String"
    end
  end
  def Array(val)
    return [] if val.nil?
    return val if val.is_a?(Array)
    skip_to_ary = false
    begin
      result = val.send(:to_ary)
      return result if result.is_a?(Array)
      skip_to_ary = result.nil?  # nil → fall through to to_a
      raise TypeError, "can't convert #{val.class} into Array (#{val.class}#to_ary gives #{result.class})" unless skip_to_ary
    rescue NoMethodError
    end
    begin
      result = val.send(:to_a)
      return result if result.is_a?(Array)
      return [val] if result.nil?
      raise TypeError, "can't convert #{val.class} into Array (#{val.class}#to_a gives #{result.class})"
    rescue NoMethodError
      [val]
    end
  end

  def Hash(val)
    return {} if val.nil? || val == []
    return val if val.is_a?(Hash)
    begin
      result = val.to_hash
      return result if result.is_a?(Hash)
      raise TypeError, "can't convert #{val.class} into Hash (#{val.class}#to_hash gives #{result.class})" unless result.nil?
    rescue NoMethodError
    end
    raise TypeError, "no implicit conversion of #{val.class} into Hash"
  end

  def putc(c)
    $stdout.putc(c)
  end

  def loop
    return to_enum(:loop) { Float::INFINITY } unless block_given?
    begin
      while true
        yield
      end
    rescue StopIteration => e
      e.result
    end
  end

  def catch(tag = nil, &block)
    raise LocalJumpError, "no block given" unless block
    # Without tag, create a new Object to use as the unique tag
    tag = Object.new if tag.nil?
    Intrinsics.kernel_catch(self, tag, block)
  end
  def throw(tag, value = nil) = Intrinsics.kernel_throw(self, tag, value)

  def open(name, *rest, **kw, &block)
    if name.respond_to?(:to_open)
      result = name.to_open(*rest, **kw)
      block ? block.call(result) : result
    else
      if rest.length > 2
        raise ArgumentError, "wrong number of arguments (given #{1 + rest.length}, expected 1..3)"
      end
      name = if name.respond_to?(:to_path)
               name.to_path
             elsif name.respond_to?(:to_str)
               name.to_str
             elsif name.is_a?(String)
               name
             else
               raise TypeError, "no implicit conversion of #{name.class} into String"
             end
      mode = rest[0]
      perm = rest[1] || 0o666
      File.open(name, mode || 'r', perm, **kw, &block)
    end
  end
  private :open

  def tap
    raise LocalJumpError, "no block given" unless block_given?
    yield self
    self
  end

  def then
    unless block_given?
      val = self
      return Enumerator.new(1) { |y| y << val }
    end
    yield self
  end
  alias yield_self then

  def at_exit(&block)
    raise ArgumentError, "called without a block" unless block
    nil  # stub: at_exit blocks not executed in frozone
  end
  def abort(msg = nil) = Intrinsics.kernel_abort(self, msg)
  def exit(code = true)
    unless code.is_a?(TrueClass) || code.is_a?(FalseClass) || code.is_a?(Integer)
      if code.respond_to?(:to_int)
        code = code.to_int
        raise TypeError, "to_int should return Integer" unless code.is_a?(Integer)
      else
        raise TypeError, "no implicit conversion of #{code.class} into Integer"
      end
    end
    Intrinsics.kernel_exit(self, code)
  end

  def exit!(code = false)
    unless code.is_a?(TrueClass) || code.is_a?(FalseClass) || code.is_a?(Integer)
      if code.respond_to?(:to_int)
        code = code.to_int
        raise TypeError, "to_int should return Integer" unless code.is_a?(Integer)
      else
        raise TypeError, "no implicit conversion of #{code.class} into Integer"
      end
    end
    Intrinsics.kernel_exit(self, code)
  end
  def rand(n = nil) = Intrinsics.kernel_rand(self, n)
  def srand(*args)
    if args.empty?
      return Intrinsics.kernel_srand(self, nil)
    end
    seed = args[0]
    if seed.nil?
      raise TypeError, "no implicit conversion of nil into Integer"
    elsif seed.is_a?(Integer)
      Intrinsics.kernel_srand(self, seed)
    elsif seed.respond_to?(:to_int)
      coerced = seed.to_int
      raise TypeError, "to_int should return Integer" unless coerced.is_a?(Integer)
      Intrinsics.kernel_srand(self, coerced)
    else
      raise TypeError, "no implicit conversion of #{seed.class} into Integer"
    end
  end
  def sleep(secs = nil)
    if secs.nil?
      # Check for cross-thread injection before blocking: Thread#raise sets
      # @raise_exception and replays the block. Injecting here gives 'sleep'
      # as the backtrace frame rather than 'stop'.
      current = Thread.current
      exc = current.__raise_exception
      if exc
        cause = current.__raise_cause
        raise_bt = current.__raise_backtrace
        current.__raise_exception = nil
        current.__raise_cause = nil
        current.__raise_backtrace = nil
        Kernel.raise exc, nil, raise_bt, cause: cause
      end
      Thread.stop
    end
    0
  end
  def system(*args) = Intrinsics.kernel_system(self, *args)
  def fork(&block) = nil  # not supported; block given to fork is never executed
  def `(cmd)
    cmd = cmd.is_a?(String) ? cmd : cmd.to_str
    Intrinsics.kernel_backtick(self, cmd)
  end
  private :"`"
  def exec(*args)
    raise NotImplementedError, "exec is not supported in Frozone"
  end
  private :exec
  def block_given? = Intrinsics.kernel_block_given(self)
  def hash = __id__
  def object_id = __id__
  def class = Intrinsics.object_class(self)
  def nil? = false
  def is_a?(klass)
    raise TypeError, "class or module required" unless Intrinsics.object_is_a(klass, Module)
    Intrinsics.object_is_a(self, klass)
  end
  alias kind_of? is_a?
  def eql?(other) = equal?(other)
  def respond_to?(name, include_all = false) = Intrinsics.object_respond_to(self, name, include_all)
  def instance_of?(klass) = Intrinsics.object_class(self).equal?(klass)
  def suppress_warning; yield; end
  def suppress_keyword_warning; yield; end
  def caller(start = 1, length = nil) = Intrinsics.kernel_caller(self, start, length)
  def caller_locations(start = 1, length = nil) = Intrinsics.kernel_caller_locations(self, start, length)
  def __method__ = Intrinsics.kernel__method__(self)
  def __callee__ = Intrinsics.kernel__callee__(self)
  def local_variables = Intrinsics.kernel_local_variables(self)
  def instance_variable_get(name)
    Intrinsics.object_ivar_get(self, __coerce_ivar_name__(name, self))
  end

  def instance_variable_set(name, value)
    Intrinsics.object_ivar_set(self, __coerce_ivar_name__(name, self), value)
  end

  def instance_variable_defined?(name)
    Intrinsics.object_ivar_defined(self, __coerce_ivar_name__(name, self))
  end

  def instance_variables = Intrinsics.object_ivar_names(self)

  def remove_instance_variable(name)
    Intrinsics.object_ivar_remove(self, __coerce_ivar_name__(name, self))
  end

  def __coerce_ivar_name__(name, receiver)
    if name.is_a?(Symbol)
      s = name.to_s
    elsif name.is_a?(String)
      s = name
    elsif name.is_a?(Integer)
      raise TypeError, "#{name.class} is not a symbol nor a string"
    elsif name.respond_to?(:to_str)
      s = name.to_str
      raise TypeError, "#{name.class}#to_str should return String" unless s.is_a?(String)
    else
      raise TypeError, "#{name.class} is not a symbol nor a string"
    end
    unless s.match?(/\A@[a-zA-Z_\u{0080}-\u{10FFFF}][a-zA-Z0-9_\u{0080}-\u{10FFFF}]*\z/)
      raise NameError.new("'#{s}' is not allowed as an instance variable name", s, receiver: receiver)
    end
    s.to_sym
  end
  private :__coerce_ivar_name__

  def to_enum(method_name = :each, *args, **kwargs, &size_block)
    Enumerator._from_method(self, method_name, args, size_block, kwargs)
  end
  alias enum_for to_enum

  def initialize_copy(source)
    return self if source.equal?(self)
    raise FrozenError, "can't modify frozen #{self.class}: #{self.inspect}" if frozen?
    raise TypeError, "initialize_copy should take same class object" unless source.is_a?(self.class)
    source.instance_variables.each do |ivar|
      instance_variable_set(ivar, source.instance_variable_get(ivar))
    end
    self
  end

  def initialize_dup(other)
    initialize_copy(other)
    self
  end

  def initialize_clone(other, freeze: nil)
    initialize_copy(other)
    self
  end
  private :initialize_copy, :initialize_dup, :initialize_clone

  def respond_to_missing?(name, include_private = false)
    false
  end
  private :respond_to_missing?

  def method(name) = Intrinsics.object_method(self, name)
  def public_method(name) = Intrinsics.object_public_method(self, name)
  def singleton_method(name) = Intrinsics.object_singleton_method(self, name)

  # Make these available as module functions: private instance methods AND public Kernel.method calls
  def autoload(name, path)
    # At the top level, autoload registers on Object (same as Module#autoload called on Object)
    Object.autoload(name, path)
  end

  def autoload?(name)
    Object.autoload?(name)
  end

  def global_variables = Intrinsics.kernel_global_variables(self)

  def spawn(*args) = Intrinsics.kernel_spawn(self, *args)

  def gets(*args) = ARGF.gets(*args)

  def readline(*args) = ARGF.readline(*args)

  def readlines(*args) = ARGF.readlines(*args)

  def select(read_ios, write_ios = nil, error_ios = nil, timeout = nil)
    IO.select(read_ios, write_ios, error_ios, timeout)
  end

  def test(cmd, file, file2 = nil)
    cmd = cmd.ord if cmd.is_a?(String)
    case cmd
    when ?f.ord then File.file?(file)
    when ?e.ord then File.exist?(file)
    when ?d.ord then File.directory?(file)
    when ?l.ord then File.symlink?(file)
    when ?r.ord then File.readable?(file)
    when ?R.ord then File.readable_real?(file)
    when ?w.ord then File.writable?(file)
    when ?W.ord then File.writable_real?(file)
    when ?x.ord then File.executable?(file)
    when ?X.ord then File.executable_real?(file)
    when ?z.ord then File.zero?(file)
    when ?s.ord then (sz = File.size?(file); sz && sz > 0 ? sz : nil)
    when ?S.ord then File.socket?(file)
    when ?p.ord then File.pipe?(file)
    when ?b.ord then File.blockdev?(file)
    when ?c.ord then File.chardev?(file)
    when ?A.ord then File.atime(file)
    when ?C.ord then File.ctime(file)
    when ?M.ord then File.mtime(file)
    when ?=.ord then file2 ? File.mtime(file) == File.mtime(file2) : false
    when ?<.ord then file2 ? File.mtime(file) < File.mtime(file2) : false
    when ?>.ord then file2 ? File.mtime(file) > File.mtime(file2) : false
    when ?-.ord then file2 ? File.identical?(file, file2) : false
    else raise ArgumentError, "unknown command ?#{cmd.chr}"
    end
  end

  def trace_var(symbol, cmd = nil, &block)
    raise ArgumentError, "tried to create Proc object without a block" if cmd.nil? && !block
    # stub: global variable tracing not supported
    nil
  end
  private :trace_var

  def untrace_var(symbol, cmd = nil)
    # stub: global variable tracing not supported
    []
  end
  private :untrace_var

  def set_trace_func(proc_obj)
    # stub: set_trace_func not supported
    nil
  end
  private :set_trace_func

  def syscall(*args)
    raise NotImplementedError, "syscall is not supported in Frozone"
  end
  private :syscall

  def trap(signal, cmd = nil, &block)
    Intrinsics.signal_register(self, signal, block || cmd)
  end
  private :trap

  module_function :puts, :print, :warn, :p, :raise, :fail, :require, :require_relative, :load, :__dir__,
                  :proc, :lambda, :eval, :binding, :sprintf, :format, :printf,
                  :Integer, :Float, :String, :Array, :Hash, :putc,
                  :loop, :catch, :throw, :abort, :exit, :exit!, :sleep, :system,
                  :block_given?, :at_exit, :caller, :caller_locations, :__method__,
                  :local_variables, :rand, :srand, :open, :"`",
                  :autoload, :autoload?, :global_variables, :spawn,
                  :gets, :readline, :readlines, :select, :test
end
