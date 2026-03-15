class Method
  def call(*args, **kwargs, &block) = Intrinsics.bound_method_call(self, args, kwargs)
  alias [] call
  alias === call
  alias yield call
  def arity           = Intrinsics.bound_method_arity(self)
  def parameters      = Intrinsics.bound_method_parameters(self)
  def name            = Intrinsics.bound_method_name(self)
  def original_name   = Intrinsics.bound_method_original_name(self)
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
    f = self
    g = other
    -> (*args, **kwargs, &blk) { g.call(f.call(*args, **kwargs, &blk)) }
  end

  def curry(arity = nil)
    to_proc.curry(arity)
  end

  def to_s
    recv_class = receiver.class
    own = owner
    param_sig = _param_sig
    loc = source_location ? " #{source_location[0]}:#{source_location[1]}" : ""
    if own && own != recv_class
      "#<Method: #{recv_class.name}(#{own.name})##{name}(#{param_sig})#{loc}>"
    else
      "#<Method: #{recv_class.name}##{name}(#{param_sig})#{loc}>"
    end
  end

  alias inspect to_s

  def _param_sig
    parts = []
    parameters.each do |type, pname|
      case type
      when :req  then parts << pname.to_s
      when :opt  then parts << "#{pname}=..."
      when :rest then parts << "*#{pname}"
      when :keyreq then parts << "#{pname}:"
      when :key    then parts << "#{pname}: ..."
      when :keyrest then parts << "**#{pname}"
      when :block  then parts << "&#{pname}"
      end
    end
    parts.join(", ")
  end

  def super_method = Intrinsics.bound_method_super(self)
end
