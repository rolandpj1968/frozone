class Module
  def include(mod) = Intrinsics.module_include(self, mod)
  def prepend(mod) = Intrinsics.module_prepend(self, mod)

  def attr_reader(*names)  = Intrinsics.module_attr_reader(self, names)
  def attr_writer(*names)  = Intrinsics.module_attr_writer(self, names)
  def attr_accessor(*names) = Intrinsics.module_attr_accessor(self, names)

  # Visibility — no-op for now (all methods are effectively public)
  def public(*names)    = nil
  def private(*names)   = nil
  def protected(*names) = nil
  def module_function(*names) = nil
end
