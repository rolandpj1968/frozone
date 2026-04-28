# Backend-independent module flattening for box-first / Crystal /
# legacy-cpp emitters.
#
# C++ (and Crystal's struct hierarchy) doesn't have a notion of mixin
# inheritance: a class either extends another class or it doesn't.
# Ruby's `include` / `prepend` semantics — module methods showing up
# in the MRO of every including class — must be flattened into each
# class's own method table at compile time.
#
# The MRI lookup order, when `obj.method_X` is called and `obj.class`
# is `cls`:
#
#     prepended modules of cls (closer to cls = higher priority)
#     cls itself
#     included modules of cls (lower priority than cls)
#     prepended modules of cls's superclass
#     cls's superclass
#     included modules of superclass
#     ...
#
# This module returns the methods that need to live on `cls`'s own
# vtable. Methods inherited via the superclass chain are emitted on
# the parent's overlay and reach `cls` through normal C++/Crystal
# class inheritance — they don't need re-flattening per child.
#
# Public API:
#
#     methods = Frozone::Compiler::ModuleFlattening.flatten(
#       cls,
#       direct_methods,    # cls's own methods_table (filtered)
#     )
#
# The returned hash is `name => Vm::Method`, in MRI priority order:
# prepend > class > include.
#
# Doesn't touch the Vm itself — pure read of `cls.ancestors_list` +
# `mod.methods_table`.

require_relative '../vm/class_object'
require_relative '../vm/module_object'

module Frozone
  module Compiler
    module ModuleFlattening
      module_function

      # Compute the methods that should live on `cls`'s own vtable.
      # `direct_methods` is the caller-filtered subset of
      # `cls.methods_table` (filtering varies by backend — e.g.
      # box-first excludes top-scope-defined methods to avoid leaks).
      #
      # Returns a Hash mapping Symbol method-name → Vm::Method, ordered
      # by MRI priority (prepend > class > include).
      def flatten(cls, direct_methods)
        prepends, includes = own_module_methods(cls)
        includes.merge(direct_methods).merge(prepends)
      end

      # Walk cls's MRO and split modules into "prepended directly" vs
      # "included directly". ancestors_list returns
      # `[prepends..., self, includes..., superclass-stuff...]`; we stop
      # at the first ClassObject after self because the superclass's
      # modules are already flattened on its own overlay and reach this
      # class via C++ inheritance.
      #
      # Returns `[prepended_methods, included_methods]` as Hashes;
      # within each, earlier MRO entries win on name conflict.
      def own_module_methods(cls)
        prepended_modules = []
        included_modules = []
        seen_self = false
        cls.ancestors_list.each do |a|
          if a.equal?(cls)
            seen_self = true
            next
          end
          break if a.is_a?(Vm::ClassObject)
          next unless a.is_a?(Vm::ModuleObject)
          (seen_self ? included_modules : prepended_modules) << a
        end
        [merge_methods(prepended_modules), merge_methods(included_modules)]
      end

      def merge_methods(modules)
        out = {}
        modules.each do |mod|
          (mod.methods_table || {}).each do |name, m|
            next unless m.is_a?(Vm::Method)
            out[name] ||= m  # earlier MRO entry wins on name conflict
          end
        end
        out
      end
    end
  end
end
