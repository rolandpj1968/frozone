module Kernel
  def to_s    = "#<#{self.class}:0x#{__id__.to_s(16)}>"
  def inspect = "#<#{self.class}:0x#{__id__.to_s(16)}>"
  def !~(other) = !(self =~ other)
  def ===(other) = self == other
  def <=>(other) = nil
  def hash = __id__
  def object_id = __id__
  def class = Intrinsics.object_class(self)
  def nil? = false
  def eql?(other) = equal?(other)
  def respond_to?(name, include_all = false) = Intrinsics.object_respond_to(self, name, include_all)
  def instance_of?(klass) = Intrinsics.object_instance_of(self, klass)
  def freeze = Intrinsics.object_freeze(self)
  def frozen? = Intrinsics.object_frozen(self)
  def methods(include_super = true) = Intrinsics.object_methods(self, include_super)
  def public_methods(include_super = true) = Intrinsics.object_public_methods(self, include_super)
  def private_methods(include_super = true) = Intrinsics.object_private_methods(self, include_super)
  def protected_methods(include_super = true) = Intrinsics.object_protected_methods(self, include_super)
  def singleton_methods(include_super = true) = Intrinsics.object_singleton_methods(self, include_super)
  def suppress_warning; yield; end
  def suppress_keyword_warning; yield; end
  def puts(*args) = Intrinsics.kernel_puts(self, args)
  def print(*args) = Intrinsics.kernel_print(self, args)
  def p(*args) = Intrinsics.kernel_p(self, args)
  def __dir__ = Intrinsics.kernel_dir(self)
  def proc(&_block) = Intrinsics.kernel_proc(self)
  def lambda(&_block) = Intrinsics.kernel_lambda(self)
  def eval(code, binding = nil, file = nil, line = nil) = Intrinsics.kernel_eval(self, code, binding, file, line)
  def binding = Intrinsics.kernel_binding(self)
  def format(fmt, *args) = sprintf(fmt, *args)
  def putc(c) = $stdout.putc(c)
  def throw(tag, value = nil) = Intrinsics.kernel_throw(self, tag, value)
  def abort(msg = nil) = Intrinsics.kernel_abort(self, msg)
  def rand(n = nil) = Intrinsics.kernel_rand(self, n)
  def system(*args) = Intrinsics.kernel_system(self, *args)
  def fork(&block) = nil  # stub; actual fork via Process._fork when supported
  def block_given? = Intrinsics.kernel_block_given(self)
  def caller(start = 1, length = nil) = Intrinsics.kernel_caller(self, start, length)
  def caller_locations(start = 1, length = nil) = Intrinsics.kernel_caller_locations(self, start, length)
  def __method__ = Intrinsics.kernel__method__(self)
  def __callee__ = Intrinsics.kernel__callee__(self)
  def local_variables = Intrinsics.kernel_local_variables(self)
  def instance_variable_get(name) = Intrinsics.object_ivar_get(self, __coerce_ivar_name__(name, self))
  def instance_variable_set(name, value) = Intrinsics.object_ivar_set(self, __coerce_ivar_name__(name, self), value)
  def instance_variable_defined?(name) = Intrinsics.object_ivar_defined(self, __coerce_ivar_name__(name, self))
  def instance_variables = Intrinsics.object_ivar_names(self)
  def remove_instance_variable(name) = Intrinsics.object_ivar_remove(self, __coerce_ivar_name__(name, self))
  def method(name) = Intrinsics.object_method(self, name)
  def public_method(name) = Intrinsics.object_public_method(self, name)
  def singleton_method(name) = Intrinsics.object_singleton_method(self, name)
  def global_variables = Intrinsics.kernel_global_variables(self)
  def spawn(*args) = Intrinsics.kernel_spawn(self, *args)
  def gets(*args) = ARGF.gets(*args)
  def readline(*args) = ARGF.readline(*args)
  def readlines(*args) = ARGF.readlines(*args)
  def require(path) = Intrinsics.kernel_require(self, __coerce_load_path__(path))
  def require_relative(path) = Intrinsics.kernel_require_relative(self, __coerce_load_path__(path))
  def load(path, wrap = false) = Intrinsics.kernel_load(self, __coerce_load_path__(path), wrap)
  def autoload?(name) = Object.autoload?(name)
  def autoload(name, path) = Object.autoload(name, path)
  def select(read_ios, write_ios = nil, error_ios = nil, timeout = nil) = IO.select(read_ios, write_ios, error_ios, timeout)
  def exit(code = true)  = __kernel_exit__(code)
  def exit!(code = false) = __kernel_exit__(code)
  def to_enum(method_name = :each, *args, **kwargs, &size_block) = Enumerator._from_method(self, method_name, args, size_block, kwargs)
  alias enum_for to_enum

  def srand(*args)
    raise TypeError, "no implicit conversion of nil into Integer" if args.size == 1 && args[0].nil?
    seed = args.empty? ? nil : __coerce_to_int__(args[0])
    Intrinsics.kernel_srand(self, seed)
  end

  def warn(*args, category: nil, uplevel: nil)
    return nil if $VERBOSE.nil? || args.empty?
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
    prefix =
      if uplevel.nil?
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

  def raise(msg = :__raise_no_arg__, message = nil, backtrace = nil, **kwargs)
    cause = kwargs.key?(:cause) ? kwargs.delete(:cause) : :__raise_no_cause__
    message = kwargs if message.nil? && !kwargs.empty?
    Intrinsics.kernel_raise(self, msg, message, backtrace, cause)
  end
  alias fail raise

  def is_a?(klass)
    raise TypeError, "class or module required" unless Intrinsics.object_is_a(klass, Module)
    Intrinsics.object_is_a(self, klass)
  end
  alias kind_of? is_a?

  def sprintf(fmt, *args)
    fmt = fmt.to_str if !fmt.is_a?(String) && fmt.respond_to?(:to_str)
    raise TypeError, "no implicit conversion of #{fmt.class} into String" unless fmt.is_a?(String)
    fmt % args
  end

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
    base =
      if raw_base.is_a?(Integer)
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
      # to_int returned non-Integer and no to_i -- raise TypeError about to_int
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
    to_s_defined =
      begin
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
    if val.respond_to?(:to_ary, true)
      result = val.__send__(:to_ary)
      return result if result.is_a?(Array)
      raise TypeError, "can't convert #{val.class} into Array (#{val.class}#to_ary gives #{result.class})" unless result.nil?
    end
    if val.respond_to?(:to_a, true)
      result = val.__send__(:to_a)
      return [val] if result.nil?
      raise TypeError, "can't convert #{val.class} into Array (#{val.class}#to_a gives #{result.class})" unless result.is_a?(Array)
      return result
    end
    [val]
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

  def open(name, *rest, **kw, &block)
    if name.respond_to?(:to_open)
      result = name.to_open(*rest, **kw)
      block ? block.call(result) : result
    else
      if rest.length > 2
        raise ArgumentError, "wrong number of arguments (given #{1 + rest.length}, expected 1..3)"
      end
      name =
        if name.respond_to?(:to_path)
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

  def `(cmd)
    cmd = __coerce_to_str__(cmd)
    Intrinsics.kernel_backtick(self, cmd)
  end

  module_function :puts, :print, :warn, :p, :raise, :fail, :require, :require_relative, :load, :__dir__,
                  :proc, :lambda, :eval, :binding, :sprintf, :format, :printf,
                  :Integer, :Float, :String, :Array, :Hash, :putc,
                  :loop, :catch, :throw, :abort, :exit, :exit!, :sleep, :system,
                  :block_given?, :at_exit, :caller, :caller_locations, :__method__,
                  :local_variables, :rand, :srand, :open, :"`",
                  :autoload, :autoload?, :global_variables, :spawn,
                  :gets, :readline, :readlines, :select, :test

  private

  def exec(*args) = raise NotImplementedError, "exec is not supported in Frozone"
  def syscall(*args) = raise NotImplementedError, "syscall is not supported in Frozone"
  def set_trace_func(proc_obj) = nil  # stub: set_trace_func not supported
  def trap(signal, cmd = nil, &block) = Intrinsics.signal_register(self, signal, block || cmd)
  def initialize_dup(other) = initialize_copy(other)
  def initialize_clone(other, freeze: nil) = initialize_copy(other)
  def respond_to_missing?(name, include_private = false) = false
  def __check_frozen__ = (raise FrozenError, "can't modify frozen #{self.class}: #{inspect}" if frozen?)

  # --- Canonical coercion helpers ---
  # Strict: raise TypeError on failure (implicit coercion protocol)

  def __coerce_to_str__(val)
    return val if val.is_a?(String)
    if val.respond_to?(:to_str)
      result = val.to_str
      raise TypeError, "can't convert #{val.class} into String (to_str should return String, not #{result.class})" unless result.is_a?(String)
      return result
    end
    raise TypeError, "no implicit conversion of #{val.class} into String"
  end

  def __coerce_to_int__(val)
    return val if val.is_a?(Integer)
    if val.respond_to?(:to_int)
      result = val.to_int
      raise TypeError, "can't convert #{val.class} into Integer (#{val.class}#to_int gives #{result.class})" unless result.is_a?(Integer)
      return result
    end
    type_name = val.nil? ? "nil" : val.class.to_s
    raise TypeError, "no implicit conversion of #{type_name} into Integer"
  end

  def __coerce_to_ary__(val)
    return val if val.is_a?(Array)
    if val.respond_to?(:to_ary)
      result = val.to_ary
      raise TypeError, "can't convert #{val.class} into Array (to_ary should return Array, not #{result.class})" unless result.is_a?(Array)
      return result
    end
    raise TypeError, "no implicit conversion of #{val.class} into Array"
  end

  def __coerce_to_hash__(val)
    return val if val.is_a?(Hash)
    if val.respond_to?(:to_hash)
      result = val.to_hash
      raise TypeError, "can't convert #{val.class} into Hash (to_hash should return Hash, not #{result.class})" unless result.is_a?(Hash)
      return result
    end
    raise TypeError, "no implicit conversion of #{val.class} into Hash"
  end

  def __coerce_to_io__(val)
    return val if val.is_a?(IO)
    if val.respond_to?(:to_io)
      result = val.to_io
      raise TypeError, "can't convert #{val.class} into IO (to_io should return IO, not #{result.class})" unless result.is_a?(IO)
      return result
    end
    raise TypeError, "no implicit conversion of #{val.class} into IO"
  end

  # Soft: return nil if object doesn't respond to the coercion method
  # (MRI rb_check_convert_type -- used where "try" semantics are needed)

  def __try_coerce_to_str__(val)
    return val if val.is_a?(String)
    return nil unless val.respond_to?(:to_str)
    result = val.to_str
    raise TypeError, "can't convert #{val.class} into String (to_str should return String, not #{result.class})" unless result.is_a?(String)
    result
  end

  def __try_coerce_to_ary__(val)
    return val if val.is_a?(Array)
    return nil unless val.respond_to?(:to_ary)
    result = val.to_ary
    raise TypeError, "can't convert #{val.class} into Array (to_ary should return Array, not #{result.class})" unless result.is_a?(Array)
    result
  end

  def __try_coerce_to_hash__(val)
    return val if val.is_a?(Hash)
    return nil unless val.respond_to?(:to_hash)
    result = val.to_hash
    raise TypeError, "can't convert #{val.class} into Hash (to_hash should return Hash, not #{result.class})" unless result.is_a?(Hash)
    result
  end

  def __try_coerce_to_io__(val)
    return val if val.is_a?(IO)
    return nil unless val.respond_to?(:to_io)
    result = val.to_io
    raise TypeError, "can't convert #{val.class} into IO (to_io should return IO, not #{result.class})" unless result.is_a?(IO)
    result
  end

  # Path coercion: to_path -> to_str chain (File/IO path arguments)
  def __coerce_to_path__(val)
    return val if val.is_a?(String)
    if val.respond_to?(:to_path)
      result = val.to_path
      return result if result.is_a?(String)
      # to_path returned non-String: try to_str on the result
      if result.respond_to?(:to_str)
        str = result.to_str
        raise TypeError, "can't convert #{result.class} into String (to_str should return String, not #{str.class})" unless str.is_a?(String)
        return str
      end
      raise TypeError, "no implicit conversion of #{val.class} into String"
    end
    if val.respond_to?(:to_str)
      result = val.to_str
      raise TypeError, "can't convert #{val.class} into String (to_str should return String, not #{result.class})" unless result.is_a?(String)
      return result
    end
    raise TypeError, "no implicit conversion of #{val.class} into String"
  end

  def __kernel_exit__(code)
    code = __coerce_to_int__(code) unless code.equal?(true) || code.equal?(false) || code.is_a?(Integer)
    Intrinsics.kernel_exit(self, code)
  end

  def __coerce_load_path__(path)
    raise TypeError, "no implicit conversion of nil into String" if path.nil?
    raise TypeError, "no implicit conversion of Integer into String" if path.is_a?(Integer)
    __coerce_to_path__(path)
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
    unless s.match?(/\A@[a-zA-Z_][a-zA-Z0-9_]*\z/)
      raise NameError.new("'#{s}' is not allowed as an instance variable name", s, receiver: receiver)
    end
    s.to_sym
  end

  def initialize_copy(source)
    raise FrozenError, "can't modify frozen #{self.class}: #{inspect}" if frozen? && !source.equal?(self)
    return self if source.equal?(self)
    raise TypeError, "initialize_copy should take same class object" unless source.instance_of?(self.class)
    source.instance_variables.each do |ivar|
      instance_variable_set(ivar, source.instance_variable_get(ivar))
    end
    self
  end

  def trace_var(symbol, cmd = nil, &block)
    raise ArgumentError, "tried to create Proc object without a block" if cmd.nil? && !block
    symbol = symbol.to_sym if symbol.is_a?(String)
    hook = cmd || block
    Intrinsics.globals_trace_var_add(self, symbol, hook)
    nil
  end

  def untrace_var(symbol, cmd = nil)
    symbol = symbol.to_sym if symbol.is_a?(String)
    Intrinsics.globals_trace_var_remove(self, symbol, cmd)
  end
end
