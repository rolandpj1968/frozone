class BasicObject
  # TODO private
  def __id__ = Intrinsics.basic_object___id__(self)
  def ! = false.equal?(self) || nil.equal?(self)
  def ==(v) = Intrinsics.basic_object__equal_equal_(self, v)
  alias eql? ==
  alias equal? ==
  def !=(v) = !(self == v)

  def initialize
  end

  def respond_to_missing?(name, include_private = false)
    false
  end
  private

  def method_missing(name, *args, **kwargs) = Intrinsics.basic_object_method_missing(self, name, args, kwargs)

  def singleton_method_added(name)
  end

  def singleton_method_removed(name)
  end

  def singleton_method_undefined(name)
  end
  public

  def __send__(name, *args, **kwargs, &block) = Intrinsics.basic_object___send__(self, name, args, kwargs, block)
  def instance_exec(*args, &block) = Intrinsics.object_instance_exec(self, args, block)

  def instance_eval(str = :__unset__, file = nil, line = nil, extra = :__unset__, &block)
    if block
      raise ArgumentError, "wrong number of arguments (given #{[str, file, line].count { |a| !a.equal?(:__unset__) && !a.nil? } + (extra.equal?(:__unset__) ? 0 : 1)}, expected 0)" unless str.equal?(:__unset__) && file.nil? && line.nil? && extra.equal?(:__unset__)
      Intrinsics.object_instance_eval(self, block)
    elsif str.equal?(:__unset__)
      raise ArgumentError, "wrong number of arguments (given 0, expected 1..3)"
    elsif !extra.equal?(:__unset__)
      raise ArgumentError, "wrong number of arguments (given 4, expected 1..3)"
    else
      Intrinsics.object_instance_eval_string(self, str, file, line)
    end
  end
end
