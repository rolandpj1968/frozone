class Module
  # Define visibility methods first so they can be used to mark others private
  def public(*names)    = Intrinsics.module_set_public(self, names)
  def private(*names)   = Intrinsics.module_set_private(self, names)
  def protected(*names) = Intrinsics.module_set_protected(self, names)

  def module_function(*names) = Intrinsics.module_function(self, names)

  private :public, :private, :protected, :module_function

  def include(*mods) = Intrinsics.module_include_multi(self, mods)
  def prepend(*mods) = Intrinsics.module_prepend_multi(self, mods)

  def append_features(other) = Intrinsics.module_append_features(self, other)
  def prepend_features(other) = Intrinsics.module_prepend_features(self, other)
  def included(other); end
  def prepended(other); end

  private :append_features, :prepend_features, :included, :prepended

  def attr_reader(*names)  = Intrinsics.module_attr_reader(self, names)
  def attr_writer(*names)  = Intrinsics.module_attr_writer(self, names)
  def attr_accessor(*names) = Intrinsics.module_attr_accessor(self, names)

  def attr(*names_and_writable)
    # Handle legacy form: attr :name, true/false
    if names_and_writable.size >= 2 && (names_and_writable.last == true || names_and_writable.last == false)
      warn "#{caller(1, 1).first}: warning: optional boolean argument is obsoleted" if $VERBOSE
      writable = names_and_writable.last
      names = names_and_writable[0..-2]
      if writable
        Intrinsics.module_attr_accessor(self, names)
      else
        Intrinsics.module_attr_reader(self, names)
      end
    else
      Intrinsics.module_attr_reader(self, names_and_writable)
    end
  end

  def module_eval(code = nil, file = nil, line = nil, extra = :__unset__, &block)
    if block
      raise ArgumentError, "wrong number of arguments (given #{[code, file, line].compact.size + (extra.equal?(:__unset__) ? 0 : 1)}, expected 0)" unless code.nil? && file.nil? && line.nil? && extra.equal?(:__unset__)
      Intrinsics.module_eval(self, block)
    elsif code.nil?
      raise ArgumentError, "wrong number of arguments (given 0, expected 1..3)"
    elsif !extra.equal?(:__unset__)
      raise ArgumentError, "wrong number of arguments (given 4, expected 1..3)"
    else
      unless code.is_a?(String)
        if code.respond_to?(:to_str)
          result = code.to_str
          raise TypeError, "can't convert #{code.class} into String (to_str should return String, not #{result.class})" unless result.is_a?(String)
          code = result
        else
          raise TypeError, "no implicit conversion of #{code.class} into String"
        end
      end
      unless file.nil? || file.is_a?(String)
        if file.respond_to?(:to_str)
          result = file.to_str
          raise TypeError, "can't convert #{file.class} into String (to_str should return String, not #{result.class})" unless result.is_a?(String)
          file = result
        else
          raise TypeError, "no implicit conversion of #{file.class} into String"
        end
      end
      Intrinsics.module_eval_string(self, code, file, line)
    end
  end

  alias class_eval module_eval

  def module_exec(*args, &block)
    raise LocalJumpError, "no block given" unless block
    Intrinsics.module_exec(self, args, block)
  end
  alias class_exec module_exec
  def private_constant(*names) = Intrinsics.module_private_constant(self, *names)
  def public_constant(*names) = Intrinsics.module_public_constant(self, *names)
  def private_class_method(*names) = Intrinsics.module_set_class_method_visibility(self, names, :private)
  def public_class_method(*names) = Intrinsics.module_set_class_method_visibility(self, names, :public)
  def remove_method(*names) = Intrinsics.module_remove_methods(self, names)
  def undef_method(*names) = Intrinsics.module_undef_methods(self, names)
  def alias_method(new_name, old_name) = Intrinsics.module_alias_method(self, new_name, old_name)
  def define_method(name, callable = :__unset__, &block)
    if callable.equal?(:__unset__)
      raise ArgumentError, "tried to create Proc object without a block" unless block
      Intrinsics.module_define_method(self, name, block)
    elsif callable.nil?
      raise TypeError, "wrong argument type NilClass (expected Proc/Method/UnboundMethod)" unless block
      Intrinsics.module_define_method(self, name, block)
    else
      Intrinsics.module_define_method(self, name, callable)
    end
  end

  def ===(other) = other.is_a?(self)

  def dup = Intrinsics.module_dup(self)

  def name            = Intrinsics.module_name(self)

  def to_s
    if @__refinement__
      refined_name = @__refined_class__ ? (@__refined_class__.name || @__refined_class__.inspect) : "?"
      container_name = @__refining_module__ ? (@__refining_module__.name || @__refining_module__.inspect) : "?"
      return "#<refinement:#{refined_name}@#{container_name}>"
    end
    n = Intrinsics.module_name(self)
    return n if n
    unless singleton_class?
      return "#<#{self.class.name}:0x#{__id__.to_s(16)}>"
    end
    target_str = Intrinsics.module_singleton_class_safe_target_str(self)
    "#<Class:#{target_str}>"
  end

  def inspect         = to_s
  def const_defined?(name, inherit = true) = Intrinsics.module_const_defined(self, name, inherit)
  def const_get(name, inherit = true) = Intrinsics.module_const_get(self, name, inherit)
  def const_set(name, value) = Intrinsics.module_const_set(self, name, value)
  def ancestors       = Intrinsics.module_ancestors(self)
  def included_modules = ancestors.drop(1).select { |m| m.is_a?(Module) && !m.is_a?(Class) }
  def include?(mod)
    raise TypeError, "wrong argument type #{mod.class} (expected Module)" unless mod.is_a?(Module) && !mod.is_a?(Class)
    ancestors.drop(1).include?(mod)
  end
  def instance_methods(include_super = true) = Intrinsics.module_instance_methods(self, include_super)
  def undefined_instance_methods = Intrinsics.module_undefined_instance_methods(self)
  def public_instance_methods(include_super = true) = Intrinsics.module_public_only_instance_methods(self, include_super)
  def private_instance_methods(include_super = true) = Intrinsics.module_private_instance_methods(self, include_super)
  def protected_instance_methods(include_super = true) = Intrinsics.module_protected_instance_methods(self, include_super)
  def instance_method(name) = Intrinsics.module_instance_method(self, name)
  def public_instance_method(name) = Intrinsics.module_public_instance_method(self, name)
  def method_defined?(name, inherit = true) = Intrinsics.module_method_defined(self, name, inherit)
  def public_method_defined?(name, inherit = true) = Intrinsics.module_public_method_defined(self, name, inherit)
  def private_method_defined?(name, inherit = true) = Intrinsics.module_private_method_defined(self, name, inherit)
  def protected_method_defined?(name, inherit = true) = Intrinsics.module_protected_method_defined(self, name, inherit)

  def constants(inherit = true) = Intrinsics.module_constants(self, inherit)
  def class_variable_defined?(name) = Intrinsics.module_class_variable_defined(self, name)
  def class_variable_get(name) = Intrinsics.module_class_variable_get(self, name)
  def class_variable_set(name, value) = Intrinsics.module_class_variable_set(self, name, value)
  def class_variables(inherit = true) = Intrinsics.module_class_variables(self, inherit)
  def remove_const(name) = Intrinsics.module_remove_const(self, name)
  private :remove_const
  def remove_class_variable(name) = Intrinsics.module_remove_class_variable(self, name)
  def ruby2_keywords(*names) = Intrinsics.module_ruby2_keywords(self, names)

  def self.nesting = Intrinsics.module_nesting(self)

  # Module.constants (no args) returns all accessible top-level constants (MRI singleton method).
  # Module.constants(true/false) uses the normal Module#constants instance-method semantics.
  def self.constants(*args)
    args.empty? ? Object.constants : Intrinsics.module_constants(self, args.first)
  end

  def autoload(name, path) = Intrinsics.module_autoload(self, name, path)
  def autoload?(name, inherit = true) = Intrinsics.module_autoload_q(self, name, inherit)
  def singleton_class? = Intrinsics.module_singleton_class_q(self)
  def set_temporary_name(name) = Intrinsics.module_set_temporary_name(self, name)
  def const_source_location(name, inherit = true) = Intrinsics.module_const_source_location(self, name, inherit)

  def const_added(name); end
  private :const_added

  def method_added(name); end
  def method_removed(name); end
  def method_undefined(name); end
  def singleton_method_added(name); end
  def singleton_method_removed(name); end
  def singleton_method_undefined(name); end
  private :method_added, :method_removed, :method_undefined
  private :singleton_method_added, :singleton_method_removed, :singleton_method_undefined

  def deprecate_constant(*names) = Intrinsics.module_deprecate_constant(self, names)

  def extend_object(obj) = Intrinsics.module_extend_object(self, obj)
  private :extend_object

  def extended(obj); end
  private :extended

  def <(other)
    raise TypeError, "compared with non class/module" unless other.is_a?(Module)
    return false if equal?(other)
    ancestors.include?(other) ? true : (other.ancestors.include?(self) ? false : nil)
  end

  def >(other)
    raise TypeError, "compared with non class/module" unless other.is_a?(Module)
    return false if equal?(other)
    other.ancestors.include?(self) ? true : (ancestors.include?(other) ? false : nil)
  end

  def <=>(other)
    return nil unless other.is_a?(Module)
    return 0 if self.equal?(other)
    return -1 if ancestors.include?(other)
    return 1 if other.ancestors.include?(self)
    nil
  end

  def <=(other)
    raise TypeError, "compared with non class/module" unless other.is_a?(Module)
    return true if self.equal?(other) || ancestors.include?(other)
    other.ancestors.include?(self) ? false : nil
  end

  def >=(other)
    raise TypeError, "compared with non class/module" unless other.is_a?(Module)
    return true if self.equal?(other) || other.ancestors.include?(self)
    ancestors.include?(other) ? false : nil
  end

  def const_missing(name)
    n = self.name
    label = (n && n != "Object") ? "#{n}::#{name}" : name.to_s
    e = NameError.new("uninitialized constant #{label}", name)
    e.instance_variable_set(:@receiver, self)
    raise e
  end

  def refine(klass = :__refine_unset__, &block)
    raise ArgumentError, "wrong number of arguments (given 0, expected 1)" if klass.equal?(:__refine_unset__)
    raise ArgumentError, "no block given" unless block
    raise TypeError, "wrong argument type #{klass.class} (expected Class or Module)" unless klass.is_a?(Module)
    # Reuse the same refinement module for repeated refine of the same class.
    # Methods defined in the block become instance methods of the refinement module.
    @__refinements__ ||= {}
    refinement = @__refinements__[klass.object_id]
    unless refinement
      refinement = Module.new
      refinement.instance_variable_set(:@__refinement__, true)
      refinement.instance_variable_set(:@__refined_class__, klass)
      refinement.instance_variable_set(:@__refining_module__, self)
      @__refinements__[klass.object_id] = refinement
    end
    # Execute the refine block with all refinements from THIS module active
    # (so methods defined in the refine block can call other refined methods)
    Intrinsics.module_refine_eval(self, refinement, block)
    refinement
  end

  def refinements
    refs = @__refinements__
    return [] unless refs
    refs.values
  end

  def using(mod)
    raise TypeError, "wrong argument type #{mod.class} (expected Module)" unless mod.is_a?(Module)
    raise TypeError, "wrong argument type Class (expected Module)" if mod.is_a?(Class)
    Intrinsics.module_using(self, mod)
    self
  end

  private :using

  def self.used_refinements = Intrinsics.module_used_refinements(self)
end
