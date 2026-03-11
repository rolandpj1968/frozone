class Class
  def new(*args, **kwargs, &block) = Intrinsics.class_new(self, args, kwargs, block)
  def ===(other) = other.is_a?(self)
  def superclass = Intrinsics.class_superclass(self)
end
