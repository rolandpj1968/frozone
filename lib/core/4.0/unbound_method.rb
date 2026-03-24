class UnboundMethod
  def parameters = Intrinsics.unbound_method_parameters(self)
  def name = Intrinsics.unbound_method_name(self)
  def original_name = Intrinsics.unbound_method_original_name(self)
  def owner = Intrinsics.unbound_method_owner(self)
  def arity = Intrinsics.unbound_method_arity(self)
  def source_location = Intrinsics.unbound_method_source_location(self)
  def bind(receiver) = Intrinsics.unbound_method_bind(self, receiver)
  def bind_call(receiver, *args, **kwargs, &block) = bind(receiver).call(*args, **kwargs, &block)
  def super_method = Intrinsics.unbound_method_super(self)
  def dup = Intrinsics.unbound_method_dup(self)
  def hash = Intrinsics.unbound_method_hash(self)

  def clone(freeze: nil)
    c = dup
    c.freeze if freeze.nil? ? frozen? : freeze
    c
  end

  def ==(other)
    return false unless other.is_a?(UnboundMethod)
    Intrinsics.unbound_method_eq(self, other)
  end

  def inspect
    own = owner
    own_name = own ? (own.name || own.inspect) : nil
    loc = source_location ? " #{source_location[0]}:#{source_location[1]}" : ""
    "#<UnboundMethod: #{own_name}##{name}#{loc}>"
  end
  alias to_s inspect
end
