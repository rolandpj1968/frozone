class Proc
  def self.new(&block) = block
  def self.allocate = raise(TypeError, "allocating an instance of Proc")
  def call(*args, **kwargs) = Intrinsics.proc_call(self, args, kwargs)
  def [](*args, **kwargs)   = Intrinsics.proc_call(self, args, kwargs)
  alias === call
  alias yield call
  def lambda?         = Intrinsics.proc_lambda_p(self)
  def arity           = Intrinsics.proc_arity(self)
  def parameters      = Intrinsics.proc_parameters(self)
  def source_location = Intrinsics.proc_source_location(self)
  def dup = Intrinsics.proc_dup(self)
  def clone(freeze: nil) = Intrinsics.proc_clone(self, freeze)

  def <<(other)
    raise TypeError, "callable object is expected" unless other.respond_to?(:call)
    is_lam = other.respond_to?(:lambda?) && other.lambda?
    f = self
    g = other
    if is_lam
      -> (*args, **kwargs, &blk) { f.call(g.call(*args, **kwargs, &blk)) }
    else
      proc { |*args, **kwargs, &blk| f.call(g.call(*args, **kwargs, &blk)) }
    end
  end

  def >>(other)
    raise TypeError, "callable object is expected" unless other.respond_to?(:call)
    is_lam = lambda?
    f = self
    g = other
    if is_lam
      -> (*args, **kwargs, &blk) { g.call(f.call(*args, **kwargs, &blk)) }
    else
      proc { |*args, **kwargs, &blk| g.call(f.call(*args, **kwargs, &blk)) }
    end
  end

  def curry(arity = nil)
    Intrinsics.proc_curry(self, arity)
  end
end
