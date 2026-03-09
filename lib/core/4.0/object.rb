class Object
  def hash = __id__

  def object_id = __id__

  def ! = Intrinsics.object_not(self)
  def !=(other) = !(self == other)
  def ===(other) = self == other

  def nil? = false

  def class = Intrinsics.object_class(self)

  def is_a?(klass) = Intrinsics.object_is_a(self, klass)
  alias kind_of? is_a?

  def instance_of?(klass) = Intrinsics.object_instance_of(self, klass)

  def respond_to?(name) = Intrinsics.object_respond_to(self, name)

  def to_s = Intrinsics.object_to_s(self)
  def inspect = to_s

  alias send __send__

  def puts(*args) = Intrinsics.kernel_puts(self, args)
  def print(*args) = Intrinsics.kernel_print(self, args)
  def p(*args) = Intrinsics.kernel_p(self, args)
  def raise(msg = nil) = Intrinsics.kernel_raise(self, msg)

  def require(path)          = Intrinsics.kernel_require(self, path)
  def require_relative(path) = Intrinsics.kernel_require_relative(self, path)
  def load(path)             = Intrinsics.kernel_load(self, path)

  def proc   = Intrinsics.kernel_proc(self)
  def lambda = Intrinsics.kernel_lambda(self)
end
