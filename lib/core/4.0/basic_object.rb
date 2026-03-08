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

  def __send__(name, *args, **kwargs) = Intrinsics.basic_object___send__(self, name, args, kwargs)

  # TODO
  # instance_eval
  # instance_exec
end
