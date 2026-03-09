class Proc
  def call(*args) = Intrinsics.proc_call(self, args)
  def [](*args)   = Intrinsics.proc_call(self, args)
end
