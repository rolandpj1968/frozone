class BasicObject
  # TODO private
  def initialize
  end

  def __id__ = Intrinsics.basic_object___id__(self)

  def ! = false.equal?(self) || nil.equal?(self)

  def ==(v) = Intrinsics.basic_object__equal_equal_(self, v)
  alias eql? ==
  alias equal? ==

  def !=(v) = !(self == v)

  def respond_to_missing?(name, include_private = false)
    false
  end

  def method_missing(name, *args, **kwargs)
    Intrinsics.basic_object_method_missing(self, name, args, kwargs)
  end

  def __send__(name, *args, **kwargs, &block)
    Intrinsics.basic_object___send__(self, name, args, kwargs, block)
  end

  # TODO
  # instance_eval
  # instance_exec
end
