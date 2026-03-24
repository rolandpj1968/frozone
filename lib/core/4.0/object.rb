class Object < BasicObject
  include Kernel

  def ! = self.equal?(nil) || self.equal?(false)
  def !=(other) = !(self == other)
  def !~(other) = !(self =~ other)
  def ===(other) = Intrinsics.object_same_object?(self, other) || self == other
  def extend(*mods) = Intrinsics.object_extend_multi(self, mods)
  def instance_exec(*args, &block) = Intrinsics.object_instance_exec(self, args, block)
  def freeze = Intrinsics.object_freeze(self)
  def frozen? = Intrinsics.object_frozen(self)
  def dup = Intrinsics.object_dup(self)
  def clone(freeze: nil) = Intrinsics.object_clone(self, freeze)
  def itself = self
  def methods(include_super = true) = Intrinsics.object_methods(self, include_super)
  def public_methods(include_super = true) = Intrinsics.object_public_methods(self, include_super)
  def private_methods(include_super = true) = Intrinsics.object_private_methods(self, include_super)
  def protected_methods(include_super = true) = Intrinsics.object_protected_methods(self, include_super)
  def singleton_methods(include_super = true) = Intrinsics.object_singleton_methods(self, include_super)
  def singleton_class = Intrinsics.object_singleton_class(self)
  def to_s = "#<#{self.class}:0x#{__id__.to_s(16)}>"
  def pretty_inspect = inspect
  def suppress_warning; yield; end
  def suppress_keyword_warning; yield; end
  def public_send(name, *args, **kwargs, &block) = Intrinsics.object_public_send(self, name, args, kwargs, block)
  alias send __send__

  def <=>(other)
    eq = (self == other)
    eq.nil? ? nil : (eq ? 0 : nil)
  end

  def instance_eval(*args, &block)
    if block
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" unless args.empty?
      Intrinsics.object_instance_eval(self, block)
    elsif args.empty?
      raise ArgumentError, "wrong number of arguments (given 0, expected 1..3)"
    elsif args.size > 3
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 1..3)"
    else
      Intrinsics.object_instance_eval_string(self, args[0], args[1], args[2])
    end
  end

  def define_singleton_method(name, callable = :__unset__, &block)
    if callable.equal?(:__unset__)
      singleton_class.define_method(name, &block)
    else
      singleton_class.define_method(name, callable)
    end
  end

  def inspect
    klass = begin; self.class; rescue NameError; nil; end
    class_part = klass ? klass.to_s : "Object"
    base = "#<#{class_part}:0x#{__id__.to_s(16)}"
    ivars =
      if respond_to?(:instance_variables_to_inspect, true)
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
end
