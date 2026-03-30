require_relative 'node'

module Frozone
  module Ast
    class MethodAlias < Node
      def initialize(new_name, old_name)
        @new_name = new_name
        @old_name = old_name
      end

      def children = [@new_name, @old_name].select { |n| n.is_a?(Node) }

      def to_s = "alias(#{@new_name}, #{old_name})"

      def evaluate(context)
        new_name = resolve_name(context, @new_name)
        old_name = resolve_name(context, @old_name)
        # Use def_scope when set (e.g. inside instance_eval/instance_exec), otherwise use lexical scope.
        clazz = context.frame.def_scope || context.scopes.last
        # Aliasing on singleton class of immutable types (Integer, Symbol, etc.) raises TypeError
        if clazz.is_singleton_class
          owner = clazz.singleton_of
          if owner && (owner.is_a?(Vm::IntegerObject) || owner.is_a?(Vm::SymbolObject) ||
                       owner.is_a?(Vm::NilObject) || owner.is_a?(Vm::TrueObject) || owner.is_a?(Vm::FalseObject))
            raise Vm::FrozoneException.make(:TypeError, "can't define singleton")
          end
        end
        method = clazz.lookup_method(old_name)
        # Inside a refine block, clazz is the refinement module. If the method isn't defined
        # on the refinement module, look for it in the refined class (e.g. `alias :x :count` should
        # find Array#count when inside `refine Array do ... end`).
        if method.nil? && clazz.is_a?(Vm::ModuleObject)
          refined_class_obj = clazz.get_ivar(:@__refined_class__)
          if refined_class_obj && !refined_class_obj.is_a?(Vm::NilObject)
            method = refined_class_obj.lookup_method(old_name)
          end
        end
        if method.nil?
          clazz_name = clazz.is_a?(Vm::ModuleObject) ? clazz.name : nil
          raise Vm::FrozoneException.make(:NameError, "undefined method '#{old_name}' for class '#{clazz_name}'")
        end
        clazz.set_method(new_name, method.alias_as(new_name))
        Vm::Intrinsics.trigger_method_added(context, clazz, new_name)
        Vm::SymbolObject.from(new_name)
      end

      private

      def resolve_name(context, name)
        return name if name.is_a?(Symbol)
        sym_obj = name.evaluate(context)
        sym_obj.is_a?(Vm::SymbolObject) ? sym_obj.raw : sym_obj.raw.to_sym
      end
    end
  end
end
