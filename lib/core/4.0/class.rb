class Class
  def initialize(superclass = nil)
    raise TypeError, "already initialized class"
  end
  private :initialize

  def new(*args, **kwargs, &block) = Intrinsics.class_new(self, args, kwargs, block)
  def allocate = Intrinsics.class_allocate(self)
  def ===(other) = other.is_a?(self)
  def superclass = Intrinsics.class_superclass(self)
  def attached_object = Intrinsics.class_attached_object(self)
  def subclasses = Intrinsics.class_subclasses(self)
  def inherited(subclass); end
  # Class undefines these Module-only methods
  undef_method :append_features, :prepend_features, :module_function, :extend_object
end
