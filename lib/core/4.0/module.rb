class Module
  def include(mod) = Intrinsics.module_include(self, mod)
  def prepend(mod) = Intrinsics.module_prepend(self, mod)

  def attr_reader(*names)  = Intrinsics.module_attr_reader(self, names)
  def attr_writer(*names)  = Intrinsics.module_attr_writer(self, names)
  def attr_accessor(*names) = Intrinsics.module_attr_accessor(self, names)

  def public(*names)    = Intrinsics.module_set_public(self, names)
  def private(*names)   = Intrinsics.module_set_private(self, names)
  def protected(*names) = Intrinsics.module_set_protected(self, names)
  def module_function(*names) = nil
end
