class Class
  def new(*args, **kwargs) = Intrinsics.class_new(self, args, kwargs)
  def ===(other) = other.is_a?(self)
end
