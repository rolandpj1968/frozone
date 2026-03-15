class Proc
  def self.new(&block) = block
  def call(*args, **kwargs) = Intrinsics.proc_call(self, args, kwargs)
  def [](*args, **kwargs)   = Intrinsics.proc_call(self, args, kwargs)
  alias === call
  alias yield call
  def lambda?         = Intrinsics.proc_lambda_p(self)
  def arity           = Intrinsics.proc_arity(self)
  def parameters      = Intrinsics.proc_parameters(self)
  def source_location = Intrinsics.proc_source_location(self)
end
