class Object < BasicObject
  include Kernel

  def ! = self == nil || self == false
  def !=(other) = !(self == other)
  def !~(other) = !(self =~ other)
  def ===(other) = self == other

  def <=>(other) = equal?(other) ? 0 : nil

  def extend(mod) = Intrinsics.object_extend(self, mod)

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
  def private_methods(include_super = true) = Intrinsics.object_private_methods(self, include_super)
  def protected_methods(include_super = true) = Intrinsics.object_protected_methods(self, include_super)
  def singleton_methods(include_super = true) = Intrinsics.object_singleton_methods(self, include_super)
  def singleton_class = Intrinsics.object_singleton_class(self)

  def define_singleton_method(name, callable = :__unset__, &block)
    if callable.equal?(:__unset__)
      singleton_class.define_method(name, &block)
    else
      singleton_class.define_method(name, callable)
    end
  end

  def to_s = "#<#{self.class}:0x#{__id__.to_s(16)}>"

  def inspect
    klass = begin; self.class; rescue NameError; nil; end
    class_part = klass ? klass.to_s : "Object"
    base = "#<#{class_part}:0x#{__id__.to_s(16)}"
    ivars = if respond_to?(:instance_variables_to_inspect, true)
      result = instance_variables_to_inspect
      if result.nil?
        instance_variables
      elsif result.is_a?(Array)
        result.select { |name| instance_variable_defined?(name) }
      else
        raise TypeError, "Expected #instance_variables_to_inspect to return an Array or nil, but it returned #{result.class}"
      end
    else
      instance_variables
    end
    if ivars.empty?
      "#{base}>"
    else
      ivar_strs = ivars.map { |name| "#{name}=#{instance_variable_get(name).inspect}" }
      "#{base} #{ivar_strs.join(', ')}>"
    end
  end

  def pretty_inspect = inspect

  def method(name) = Intrinsics.object_method(self, name)
  def public_method(name) = Intrinsics.object_public_method(self, name)
  def singleton_method(name) = Intrinsics.object_singleton_method(self, name)

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
  def super_method    = Intrinsics.unbound_method_super(self)
  def dup             = Intrinsics.unbound_method_dup(self)
  def hash            = Intrinsics.unbound_method_hash(self)

  def clone(freeze: nil)
    c = dup
    should_freeze = freeze.nil? ? frozen? : freeze
    c.freeze if should_freeze
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

module Warning
  KNOWN_CATEGORIES = %i[deprecated experimental performance strict_unused_block unused_block].freeze

  # Use parallel arrays instead of a Hash to avoid Symbol#hash ordering issues
  # (object.rb loads before symbol.rb, so Hash uses __id__ as hash function).
  @cat_keys = [:deprecated, :experimental, :performance, :strict_unused_block, :unused_block]
  @cat_vals = [true, true, false, false, false]

  extend self

  def self.[](category)
    raise TypeError, "wrong argument type #{category.class} (expected Symbol)" unless category.is_a?(Symbol)
    idx = @cat_keys.index { |k| k == category }
    raise ArgumentError, "unknown category: #{category}" unless idx
    @cat_vals[idx]
  end

  def self.[]=(category, value)
    raise TypeError, "wrong argument type #{category.class} (expected Symbol)" unless category.is_a?(Symbol)
    idx = @cat_keys.index { |k| k == category }
    raise ArgumentError, "unknown category: #{category}" unless idx
    @cat_vals[idx] = value ? true : false
  end

  def self.categories = KNOWN_CATEGORIES

  def self.warn(msg, category: nil)
    return nil if category && !self[category]
    $stderr.write(msg)
    nil
  end
end
