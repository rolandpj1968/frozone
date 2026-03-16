class Object < BasicObject
  include Kernel

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
  def itself = self
  def then(&block) = block ? block.call(self) : self
  alias yield_self then

  def methods(include_super = true) = Intrinsics.object_methods(self, include_super)
  def public_methods(include_super = true) = Intrinsics.object_public_methods(self, include_super)
  def private_methods(include_super = true) = []
  def protected_methods(include_super = true) = []
  def singleton_methods(include_super = true) = Intrinsics.object_singleton_methods(self, include_super)
  def singleton_class = Intrinsics.object_singleton_class(self)

  def define_singleton_method(name, &block)
    singleton_class.define_method(name, &block)
  end

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
  def parameters      = Intrinsics.unbound_method_parameters(self)
  def name            = Intrinsics.unbound_method_name(self)
  def original_name   = Intrinsics.unbound_method_original_name(self)
  def owner           = Intrinsics.unbound_method_owner(self)
  def arity           = Intrinsics.unbound_method_arity(self)
  def source_location = Intrinsics.unbound_method_source_location(self)
  def bind(receiver)  = Intrinsics.unbound_method_bind(self, receiver)
  def bind_call(receiver, *args, **kwargs, &block) = bind(receiver).call(*args, **kwargs, &block)
end

module Warning
  KNOWN_CATEGORIES = %i[deprecated experimental performance strict_unused_block unused_block].freeze

  @categories = { deprecated: false, experimental: true, performance: false,
                  strict_unused_block: false, unused_block: false }

  extend self

  def self.[](category)
    raise TypeError, "wrong argument type #{category.class} (expected Symbol)" unless category.is_a?(Symbol)
    raise ArgumentError, "unknown category: #{category}" unless KNOWN_CATEGORIES.include?(category)
    @categories[category]
  end

  def self.[]=(category, value)
    raise TypeError, "wrong argument type #{category.class} (expected Symbol)" unless category.is_a?(Symbol)
    raise ArgumentError, "unknown category: #{category}" unless KNOWN_CATEGORIES.include?(category)
    @categories[category] = value ? true : false
  end

  def self.categories = KNOWN_CATEGORIES

  def self.warn(msg, category: nil)
    Kernel.warn(msg)
  end
end
