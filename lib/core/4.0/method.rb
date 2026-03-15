class Method
  def call(*args, **kwargs, &block) = Intrinsics.bound_method_call(self, args, kwargs)
  alias [] call
  alias === call
  alias yield call
  def arity           = Intrinsics.bound_method_arity(self)
  def parameters      = Intrinsics.bound_method_parameters(self)
  def name            = Intrinsics.bound_method_name(self)
  def original_name   = Intrinsics.bound_method_name(self)
  def owner           = Intrinsics.bound_method_owner(self)
  def receiver        = Intrinsics.bound_method_receiver(self)
  def unbind          = Intrinsics.bound_method_unbind(self)
  def source_location = Intrinsics.bound_method_source_location(self)

  def ==(other) = Intrinsics.bound_method_eql(self, other)
  alias eql? ==

  def dup = Intrinsics.bound_method_dup(self)
  def clone(freeze: nil) = Intrinsics.bound_method_dup(self)

  def hash = Intrinsics.bound_method_hash(self)

  def to_proc
    m = self
    lambda { |*args, **kwargs, &blk| m.call(*args, **kwargs, &blk) }
  end

  def <<(other)
    raise TypeError, "callable object is expected" unless other.respond_to?(:call)
    f = self
    g = other
    -> (*args, **kwargs, &blk) { f.call(g.call(*args, **kwargs, &blk)) }
  end

  def >>(other)
    raise TypeError, "callable object is expected" unless other.respond_to?(:call)
    f = self
    g = other
    -> (*args, **kwargs, &blk) { g.call(f.call(*args, **kwargs, &blk)) }
  end

  def curry(arity = nil)
    to_proc.curry(arity)
  end

  def to_s
    "#<Method: #{receiver.class}##{name}>"
  end

  alias inspect to_s

  def super_method = Intrinsics.bound_method_super(self)
end
