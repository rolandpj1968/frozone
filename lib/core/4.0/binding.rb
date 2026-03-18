class Binding
  def local_variables = Intrinsics.binding_local_variables(self)
  def local_variable_get(name) = Intrinsics.binding_local_variable_get(self, name)
  def local_variable_set(name, val) = Intrinsics.binding_local_variable_set(self, name, val)
  def local_variable_defined?(name) = Intrinsics.binding_local_variable_defined_q(self, name)
  def eval(code, file = nil, line = nil) = Intrinsics.binding_eval(self, code, file, line)
  def receiver = Intrinsics.binding_receiver(self)
  def source_location = Intrinsics.binding_source_location(self)
  def dup = Intrinsics.binding_dup(self)

  def clone(freeze: nil)
    c = dup
    if freeze.nil?
      c.freeze if frozen?
    elsif freeze
      c.freeze
    end
    c
  end
end
