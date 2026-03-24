class BasicObject
  def __id__ = Intrinsics.basic_object___id__(self)
  def ! = false.equal?(self) || nil.equal?(self)
  def ==(v) = Intrinsics.basic_object__equal_equal_(self, v)
  alias eql? ==
  alias equal? ==
  def !=(v) = !(self == v)
  def __send__(name, *args, **kwargs, &block) = Intrinsics.basic_object___send__(self, name, args, kwargs, block)
  def instance_exec(*args, &block) = Intrinsics.object_instance_exec(self, args, block)

  def instance_eval(str = :__unset__, file = nil, line = nil, &block)
    if block
      raise ArgumentError, "wrong number of arguments (given #{[str, file, line].count { |a| !a.equal?(:__unset__) && !a.nil? }}, expected 0)" unless str.equal?(:__unset__) && file.nil? && line.nil?
      Intrinsics.object_instance_eval(self, block)
    elsif str.equal?(:__unset__)
      raise ArgumentError, "wrong number of arguments (given 0, expected 1..3)"
    else
      Intrinsics.object_instance_eval_string(self, str, file, line)
    end
  end

  private

  def initialize = nil
  def respond_to_missing?(name, include_private = false) = false
  def method_missing(name, *args, **kwargs) = Intrinsics.basic_object_method_missing(self, name, args, kwargs)
  def singleton_method_added(name) = nil
  def singleton_method_removed(name) = nil
  def singleton_method_undefined(name) = nil
end
