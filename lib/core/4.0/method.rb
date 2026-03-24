class Method
  def call(*args, **kwargs, &block) = Intrinsics.bound_method_call(self, args, kwargs)
  alias [] call
  alias === call
  alias yield call
  def arity = Intrinsics.bound_method_arity(self)
  def parameters = Intrinsics.bound_method_parameters(self)
  def name = Intrinsics.bound_method_name(self)
  def original_name = Intrinsics.bound_method_original_name(self)
  def owner = Intrinsics.bound_method_owner(self)
  def receiver = Intrinsics.bound_method_receiver(self)
  def unbind = Intrinsics.bound_method_unbind(self)
  def source_location = Intrinsics.bound_method_source_location(self)
  def ==(other) = Intrinsics.bound_method_eql(self, other)
  alias eql? ==
  def dup = Intrinsics.bound_method_dup(self)
  def hash = Intrinsics.bound_method_hash(self)
  def to_proc = Intrinsics.bound_method_to_proc(self)
  def super_method = Intrinsics.bound_method_super(self)
  def curry(arity = nil) = to_proc.curry(arity)

  def clone(freeze: nil)
    frozen_val = freeze.nil? ? frozen? : freeze
    Intrinsics.bound_method_dup(self, frozen_val)
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

  def to_s
    recv = receiver
    own = owner
    param_sig = __param_sig__
    loc = source_location ? " #{source_location[0]}:#{source_location[1]}" : ""

    # Singleton method defined directly on receiver's singleton class
    # Detect: own is receiver's singleton class
    if !recv.is_a?(Class) && recv.respond_to?(:singleton_class) &&
       (own_sc = recv.singleton_class rescue nil) && own_sc.equal?(own)
      recv_str = recv.inspect.sub(/0x[0-9a-f]+/, '0x%x' % recv.__id__)
      return "#<Method: #{recv_str}.#{name}(#{param_sig})#{loc}>"
    end

    recv_is_class = recv.is_a?(Class)
    if recv_is_class
      # Receiver IS a class: use #<Class:Name> format
      recv_name = recv.name ? "#<Class:#{recv.name}>" : "#<Class:#{recv.inspect}>"
      own_name = own ? (own.name || own.inspect) : nil
      if own_name && own != recv
        "#<Method: #{recv_name}(#{own_name})##{name}(#{param_sig})#{loc}>"
      else
        "#<Method: #{recv_name}##{name}(#{param_sig})#{loc}>"
      end
    else
      recv_class = recv.class
      own_name = own ? (own.name || own.inspect) : nil
      if own_name && own != recv_class
        "#<Method: #{recv_class.name}(#{own_name})##{name}(#{param_sig})#{loc}>"
      else
        "#<Method: #{recv_class.name}##{name}(#{param_sig})#{loc}>"
      end
    end
  end
  alias inspect to_s

  def __param_sig__
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
end
