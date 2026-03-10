class Proc
  def self.new(&block) = block
  def call(*args) = Intrinsics.proc_call(self, args)
  def [](*args)   = Intrinsics.proc_call(self, args)
  alias === call
  alias yield call
end
