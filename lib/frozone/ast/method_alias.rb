require_relative 'node'

module Frozone
  module Ast
    class MethodAlias < Node
      def initialize(new_name, old_name)
        @new_name = new_name
        @old_name = old_name
      end

      def to_s
        "alias(#{@new_name}, #{old_name})"
      end

      def evaluate(context)
        new_name = resolve_name(context, @new_name)
        old_name = resolve_name(context, @old_name)
        # Use def_scope when set (e.g. inside instance_eval/instance_exec), otherwise use lexical scope.
        clazz = context.frame.def_scope || context.scopes.last
        # Aliasing on singleton class of immutable types (Integer, Symbol, etc.) raises TypeError
        if clazz.instance_variable_get(:@is_singleton_class)
          owner = clazz.instance_variable_get(:@singleton_of)
          if owner && (owner.is_a?(Vm::IntegerObject) || owner.is_a?(Vm::SymbolObject) ||
                       owner.is_a?(Vm::NilObject) || owner.is_a?(Vm::TrueObject) || owner.is_a?(Vm::FalseObject))
            raise Vm::FrozoneException.make(:TypeError, "can't define singleton")
          end
        end
        method = clazz.lookup_method(old_name)
        if method.nil?
          clazz_name = clazz.respond_to?(:name) ? clazz.name : nil
          raise Vm::FrozoneException.make(:NameError, "undefined method '#{old_name}' for class '#{clazz_name}'")
        end
        clazz.set_method(new_name, method.alias_as(new_name))
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
