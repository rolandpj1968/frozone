module Kernel
  def puts(*args) = Intrinsics.kernel_puts(self, args)
  def print(*args) = Intrinsics.kernel_print(self, args)
  def warn(*args) = Intrinsics.kernel_warn(self, args)
  def p(*args) = Intrinsics.kernel_p(self, args)
  def raise(msg = nil, message = nil, backtrace = nil) = Intrinsics.kernel_raise(self, msg, message, backtrace)
  def fail(msg = nil, message = nil, backtrace = nil) = Intrinsics.kernel_raise(self, msg, message, backtrace)

  def require(path)          = Intrinsics.kernel_require(self, path)
  def require_relative(path) = Intrinsics.kernel_require_relative(self, path)
  def load(path, wrap = false) = Intrinsics.kernel_load(self, path)
  def __dir__                = Intrinsics.kernel_dir(self)

  def proc   = Intrinsics.kernel_proc(self)
  def lambda = Intrinsics.kernel_lambda(self)

  def eval(code, binding = nil, _file = nil, _line = nil) = Intrinsics.kernel_eval(self, code, binding)
  def binding = Intrinsics.kernel_binding(self)

  def sprintf(fmt, *args) = fmt % args
  def format(fmt, *args) = fmt % args

  def Integer(val, base = 10) = Intrinsics.kernel_integer(self, val, base)
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
  def suppress_warning; yield; end
  def suppress_keyword_warning; yield; end

  def caller(start = 1, length = nil) = Intrinsics.kernel_caller(self, start, length)
  def caller_locations(start = 1, length = nil) = []
  def __method__ = nil  # stub
  def local_variables = Intrinsics.kernel_local_variables(self)

  def to_enum(method_name = :each, *args, &size_block)
    Enumerator._from_method(self, method_name, args, size_block)
  end

  alias enum_for to_enum

  # Make these available as module functions: private instance methods AND public Kernel.method calls
  module_function :puts, :print, :warn, :p, :raise, :fail, :require, :require_relative, :load, :__dir__,
                  :proc, :lambda, :eval, :binding, :sprintf, :format,
                  :Integer, :Float, :String, :Array,
                  :loop, :catch, :throw, :abort, :exit, :exit!, :sleep, :system,
                  :block_given?, :at_exit, :caller, :caller_locations, :__method__,
                  :local_variables, :rand, :srand
end
