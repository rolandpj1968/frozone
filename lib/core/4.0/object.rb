class Object
  def hash = __id__

  def object_id = __id__

  def ! = self == nil || self == false
  def !=(other) = !(self == other)
  def !~(other) = !(self =~ other)
  def ===(other) = self == other

  def nil? = false

  def class = Intrinsics.object_class(self)

  def is_a?(klass) = Intrinsics.object_is_a(self, klass)
  alias kind_of? is_a?

  def instance_of?(klass) = self.class == klass

  def respond_to?(name, include_all = false) = Intrinsics.object_respond_to(self, name, include_all)

  def instance_variable_get(name) = Intrinsics.object_ivar_get(self, name)
  def instance_variable_set(name, value) = Intrinsics.object_ivar_set(self, name, value)
  def instance_variable_defined?(name) = Intrinsics.object_ivar_defined(self, name)
  def instance_variables = Intrinsics.object_ivar_names(self)
  def remove_instance_variable(name) = Intrinsics.object_ivar_remove(self, name)

  def extend(mod) = Intrinsics.object_extend(self, mod)

  def instance_eval(str = nil, &block)
    return Intrinsics.object_instance_eval_string(self, str) if str && block.nil?
    Intrinsics.object_instance_eval(self, block)
  end

  def instance_exec(*args, &block) = Intrinsics.object_instance_exec(self, args, block)

  def freeze = Intrinsics.object_freeze(self)
  def frozen? = Intrinsics.object_frozen(self)
  def dup = Intrinsics.object_dup(self)
  def clone(freeze: nil) = Intrinsics.object_clone(self, freeze)
  def tap
    yield self if block_given?
    self
  end
  def then(&block) = block ? block.call(self) : self
  alias yield_self then

  def methods(include_super = true) = Intrinsics.object_methods(self, include_super)
  def public_methods(include_super = true) = Intrinsics.object_public_methods(self, include_super)
  def private_methods(include_super = true) = []
  def protected_methods(include_super = true) = []
  def singleton_methods(include_super = true) = Intrinsics.object_singleton_methods(self, include_super)
  def singleton_class = Intrinsics.object_singleton_class(self)

  def to_s = "#<#{self.class.name}:0x#{__id__.to_s(16)}>"
  def inspect = to_s
  def pretty_inspect = inspect

  def method(name) = Intrinsics.object_method(self, name)

  alias send __send__

  def public_send(name, *args, **kwargs, &block)
    Intrinsics.object_public_send(self, name, args, kwargs, block)
  end

  def suppress_warning; yield; end
  def suppress_keyword_warning; yield; end
end

class UnboundMethod
  def parameters = Intrinsics.unbound_method_parameters(self)
  def name = Intrinsics.unbound_method_name(self)
  def owner = Intrinsics.unbound_method_owner(self)
end

module Warning
  @categories = {}

  def self.[](category)
    @categories.key?(category) ? @categories[category] : false
  end

  def self.[]=(category, value)
    @categories[category] = value
  end

  def self.warn(msg, category: nil) = Kernel.warn(msg)
end
