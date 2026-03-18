module Kernel
  def puts(*args) = Intrinsics.kernel_puts(self, args)
  def print(*args) = Intrinsics.kernel_print(self, args)
  def warn(*args, category: nil, uplevel: nil)
    return nil if args.empty?
    category = category.to_sym if category.is_a?(String)
    return nil if category && !Warning[category]
    args.each do |msg|
      str = msg.to_s
      str += "\n" unless str.end_with?("\n")
      Warning.warn(str, category: category)
    end
    nil
  end
  def p(*args) = Intrinsics.kernel_p(self, args)
  def raise(msg = :__raise_no_arg__, message = nil, backtrace = nil, cause: :__raise_no_cause__)
    Intrinsics.kernel_raise(self, msg, message, backtrace, cause)
  end

  def fail(msg = :__raise_no_arg__, message = nil, backtrace = nil, cause: :__raise_no_cause__)
    Intrinsics.kernel_raise(self, msg, message, backtrace, cause)
  end

  def require(path)          = Intrinsics.kernel_require(self, path)
  def require_relative(path) = Intrinsics.kernel_require_relative(self, path)
  def load(path, wrap = false) = Intrinsics.kernel_load(self, path, wrap)
  def __dir__                = Intrinsics.kernel_dir(self)

  def proc   = Intrinsics.kernel_proc(self)
  def lambda = Intrinsics.kernel_lambda(self)

  def eval(code, binding = nil, file = nil, line = nil) = Intrinsics.kernel_eval(self, code, binding, file, line)
  def binding = Intrinsics.kernel_binding(self)

  def sprintf(fmt, *args) = fmt % args
  def format(fmt, *args) = fmt % args

  def Integer(val, base = 0, exception: true) = Intrinsics.kernel_integer(self, val, base, exception)
  def Float(val)              = Intrinsics.kernel_float(self, val)
  def String(val)             = val.to_s
  def Array(val)              = Intrinsics.kernel_array(self, val)

  def loop(&block) = Intrinsics.kernel_loop(self, block)

  def catch(tag = nil, &block) = Intrinsics.kernel_catch(self, tag || :__catch_anon__, block)
  def throw(tag, value = nil) = Intrinsics.kernel_throw(self, tag, value)

  def at_exit(&block) = nil  # stub: at_exit blocks not executed in frozone
  def abort(msg = nil) = Intrinsics.kernel_abort(self, msg)
  def exit(code = 0) = Intrinsics.kernel_exit(self, code)
  def exit!(code = 1) = Intrinsics.kernel_exit(self, code)
  def rand(n = nil) = Intrinsics.kernel_rand(self, n)
  def srand(seed = nil) = Intrinsics.kernel_srand(self, seed)
  def sleep(secs = nil) = nil
  def system(*args) = false
  def `(cmd) = Intrinsics.kernel_backtick(self, cmd)
  def block_given? = Intrinsics.kernel_block_given(self)
  def hash = __id__
  def object_id = __id__
  def class = Intrinsics.object_class(self)
  def nil? = false
  def is_a?(klass) = Intrinsics.object_is_a(self, klass)
  alias kind_of? is_a?
  def respond_to?(name, include_all = false) = Intrinsics.object_respond_to(self, name, include_all)
  def instance_of?(klass) = Intrinsics.object_class(self).equal?(klass)

  def suppress_warning; yield; end
  def suppress_keyword_warning; yield; end

  def caller(start = 1, length = nil) = Intrinsics.kernel_caller(self, start, length)
  def caller_locations(start = 1, length = nil) = Intrinsics.kernel_caller_locations(self, start, length)
  def __method__ = Intrinsics.kernel__method__(self)
  def local_variables = Intrinsics.kernel_local_variables(self)

  def to_enum(method_name = :each, *args, **kwargs, &size_block)
    Enumerator._from_method(self, method_name, args, size_block, kwargs)
  end

  alias enum_for to_enum

  def instance_variable_get(name) = Intrinsics.object_ivar_get(self, name)
  def instance_variable_set(name, value) = Intrinsics.object_ivar_set(self, name, value)
  def instance_variable_defined?(name) = Intrinsics.object_ivar_defined(self, name)
  def instance_variables = Intrinsics.object_ivar_names(self)
  def remove_instance_variable(name) = Intrinsics.object_ivar_remove(self, name)

  def initialize_copy(source)
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

  # Make these available as module functions: private instance methods AND public Kernel.method calls
  def autoload(name, path)
    # At the top level, autoload registers on Object (same as Module#autoload called on Object)
    Object.autoload(name, path)
  end

  def autoload?(name)
    Object.autoload?(name)
  end

  module_function :puts, :print, :warn, :p, :raise, :fail, :require, :require_relative, :load, :__dir__,
                  :proc, :lambda, :eval, :binding, :sprintf, :format,
                  :Integer, :Float, :String, :Array,
                  :loop, :catch, :throw, :abort, :exit, :exit!, :sleep, :system,
                  :block_given?, :at_exit, :caller, :caller_locations, :__method__,
                  :local_variables, :rand, :srand
end
