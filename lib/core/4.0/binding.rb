class Binding
  def local_variables = Intrinsics.binding_local_variables(self)
  def eval(code, file = nil, line = nil) = Intrinsics.binding_eval(self, code, file, line)
  def receiver = Intrinsics.binding_receiver(self)
end
