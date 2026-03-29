class Proc
  def self.new(*args) = Intrinsics.proc_class_new(self, args)
  def self.allocate = raise(TypeError, "allocating an instance of Proc")
  def call(*args, **kwargs) = Intrinsics.proc_call(self, args, kwargs)
  def [](*args, **kwargs) = Intrinsics.proc_call(self, args, kwargs)
  alias === call
  alias yield call
  def lambda? = Intrinsics.proc_lambda_p(self)
  def arity = Intrinsics.proc_arity(self)
  def parameters(lambda: nil) = Intrinsics.proc_parameters(self, lambda)
  def source_location = Intrinsics.proc_source_location(self)
  def dup = Intrinsics.proc_dup(self)
  def clone(freeze: nil) = Intrinsics.proc_clone(self, freeze)
  def to_s = Intrinsics.proc_inspect(self)
  def inspect = Intrinsics.proc_inspect(self)
  def to_proc = self
  def ==(other) = Intrinsics.proc_eql(self, other)
  def eql?(other) = Intrinsics.proc_eql(self, other)
  def hash = Intrinsics.proc_hash(self)
  def ruby2_keywords = Intrinsics.proc_ruby2_keywords(self)
  def curry(arity = nil) = Intrinsics.proc_curry(self, arity)

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

  def binding
    raise ArgumentError, "can't create Binding from curried Proc" if Intrinsics.proc_is_curried(self)
    Intrinsics.proc_binding(self)
  end
end
