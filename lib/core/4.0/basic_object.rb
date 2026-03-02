class BasicObject
  def __id__ = Intrinsics.basic_object___id__(self)

  def ! = false.equal?(self) || nil.equal?(self)

  def ==(v) = Intrinsics.basic_object__equal_equal_(self, v)
  alias eql? ==
  alias equal? ==

  def !=(v) = !(self == v)

  # TODO
  # __send__
  # instance_eval
  # instance_exec
end
