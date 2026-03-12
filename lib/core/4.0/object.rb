class Object
  def hash = __id__

  def object_id = __id__

  def ! = Intrinsics.object_not(self)
  def !=(other) = !(self == other)
  def !~(other) = !(self =~ other)
  def ===(other) = self == other

  def nil? = false

  def class = Intrinsics.object_class(self)

  def is_a?(klass) = Intrinsics.object_is_a(self, klass)
  alias kind_of? is_a?

  def instance_of?(klass) = Intrinsics.object_instance_of(self, klass)

  def respond_to?(name, include_all = false) = Intrinsics.object_respond_to(self, name)

  def instance_variable_get(name) = Intrinsics.object_ivar_get(self, name)
  def instance_variable_set(name, value) = Intrinsics.object_ivar_set(self, name, value)
  def instance_variable_defined?(name) = Intrinsics.object_ivar_defined(self, name)
  def instance_variables = Intrinsics.object_ivar_names(self)

  def extend(mod) = Intrinsics.object_extend(self, mod)
  def instance_eval(&block) = Intrinsics.object_instance_eval(self, block)
  def instance_exec(*args, &block) = Intrinsics.object_instance_exec(self, args, block)

  def freeze = self
  def frozen? = false
  def dup = self
  def clone = self
  def tap(&block) = self
  def then(&block) = block ? block.call(self) : self
  alias yield_self then

  def methods(include_super = true) = Intrinsics.object_methods(self, include_super)
  def public_methods(include_super = true) = Intrinsics.object_public_methods(self, include_super)
  def private_methods(include_super = true) = []
  def protected_methods(include_super = true) = []
  def singleton_methods(include_super = true) = Intrinsics.object_singleton_methods(self, include_super)

  def to_s = Intrinsics.object_to_s(self)
  def inspect = to_s
  def pretty_inspect = inspect

  alias send __send__

  def puts(*args) = Intrinsics.kernel_puts(self, args)
  def print(*args) = Intrinsics.kernel_print(self, args)
  def p(*args) = Intrinsics.kernel_p(self, args)
  def raise(msg = nil, message = nil, backtrace = nil) = Intrinsics.kernel_raise(self, msg, message, backtrace)

  def require(path)          = Intrinsics.kernel_require(self, path)
  def require_relative(path) = Intrinsics.kernel_require_relative(self, path)
  def load(path)             = Intrinsics.kernel_load(self, path)
  def __dir__                = Intrinsics.kernel_dir(self)

  def proc   = Intrinsics.kernel_proc(self)
  def lambda = Intrinsics.kernel_lambda(self)

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
  def sleep(secs = nil) = nil
  def system(*args) = false
  def suppress_warning; yield; end
  def suppress_keyword_warning; yield; end

  def caller(start = 1, length = nil) = []  # stub: no real backtrace in frozone
  def caller_locations(start = 1, length = nil) = []
  def __method__ = nil  # stub
end

class UnboundMethod
  def parameters = Intrinsics.unbound_method_parameters(self)
  def name = Intrinsics.unbound_method_name(self)
  def owner = Intrinsics.unbound_method_owner(self)
end
