class Module
  def include(mod) = Intrinsics.module_include(self, mod)
  def prepend(mod) = Intrinsics.module_prepend(self, mod)
end
