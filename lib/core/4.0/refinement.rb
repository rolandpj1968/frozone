class Refinement < Module
  # Refinement#include raises TypeError (removed in Ruby 3.4+)
  def include(*mods)
    raise TypeError, "Refinement#include has been removed"
  end

  # Refinement#prepend raises TypeError (removed in Ruby 3.4+)
  def prepend(*mods)
    raise TypeError, "Refinement#prepend has been removed"
  end

  # target returns the class/module refined by this refinement
  def target
    @__refined_class__
  end

  # import_methods copies instance methods from the given modules into this refinement.
  # Only methods defined in Ruby code can be imported (not C-level/intrinsic methods).
  # Raises TypeError if any argument is not a Module (or is a Class) — checked before any import.
  # Raises ArgumentError if a method is not defined in Ruby code — modules before it are still imported.
  def import_methods(*modules)
    # Type validation first: raise TypeError before importing anything if any arg is wrong type.
    modules.each do |mod|
      unless mod.is_a?(Module) && !mod.is_a?(Class)
        raise TypeError, "wrong argument type #{mod.class} (expected Module)"
      end
    end
    warn_ancestors(modules)
    # Import module by module. Each module is validated then imported before moving to the next.
    # This means modules listed before a problematic one are fully imported.
    modules.each do |mod|
      mod.instance_methods(false).each do |name|
        m = mod.instance_method(name)
        unless Intrinsics.method_ruby_defined_q(m)
          raise ArgumentError, "Can't import method which is not defined with Ruby code: #{mod.name}##{name}"
        end
        Intrinsics.refinement_import_method(self, name, m)
      end
    end
    self
  end

  private :import_methods

  # Refinement modules cannot use append_features, prepend_features, or extend_object
  undef_method :append_features
  undef_method :prepend_features
  undef_method :extend_object

  private

  def warn_ancestors(modules)
    modules.each do |mod|
      unless mod.ancestors.drop(1).select { |a| a.is_a?(Module) && !a.is_a?(Class) }.empty?
        warn "warning: #{mod} has ancestors, but Refinement#import_methods doesn't import their methods"
      end
    end
  end
end
