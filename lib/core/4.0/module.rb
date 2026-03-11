class Module
  def include(mod) = Intrinsics.module_include(self, mod)
  def prepend(mod) = Intrinsics.module_prepend(self, mod)

  def attr_reader(*names)  = Intrinsics.module_attr_reader(self, names)
  def attr_writer(*names)  = Intrinsics.module_attr_writer(self, names)
  def attr_accessor(*names) = Intrinsics.module_attr_accessor(self, names)
  alias attr attr_reader

  def public(*names)    = Intrinsics.module_set_public(self, names)
  def private(*names)   = Intrinsics.module_set_private(self, names)
  def protected(*names) = Intrinsics.module_set_protected(self, names)
  def module_function(*names) = nil
  def module_eval(&block) = Intrinsics.module_eval(self, block)
  alias class_eval module_eval
  def private_constant(*names) = self
  def public_constant(*names) = self
  def private_class_method(*names) = self
  def public_class_method(*names) = self
  def remove_method(*names) = self
  def undef_method(*names) = self
  def alias_method(new_name, old_name) = Intrinsics.module_alias_method(self, new_name, old_name)
  def define_method(name, callable = nil, &block) = Intrinsics.module_define_method(self, name, callable || block)

  def name            = Intrinsics.module_name(self)
  def to_s            = Intrinsics.module_name(self) || Intrinsics.object_to_s(self)
  def inspect         = Intrinsics.module_name(self) || Intrinsics.object_to_s(self)
  def const_defined?(name, inherit = true) = Intrinsics.module_const_defined(self, name, inherit)
  def const_get(name) = Intrinsics.module_const_get(self, name)
  def ancestors       = Intrinsics.module_ancestors(self)
  def instance_methods(include_super = true) = Intrinsics.module_instance_methods(self, include_super)
  def public_instance_methods(include_super = true) = Intrinsics.module_instance_methods(self, include_super)
  def private_instance_methods(include_super = true) = []
  def protected_instance_methods(include_super = true) = []
  def method_defined?(name) = Intrinsics.module_method_defined(self, name)
  def public_method_defined?(name) = Intrinsics.module_method_defined(self, name)
  def private_method_defined?(name) = false
  def protected_method_defined?(name) = false

  def constants(inherit = true) = Intrinsics.module_constants(self)
  def class_variable_defined?(name) = Intrinsics.module_class_variable_defined(self, name)
  def class_variables = Intrinsics.module_class_variables(self)
  def remove_const(name) = Intrinsics.module_remove_const(self, name)
end
