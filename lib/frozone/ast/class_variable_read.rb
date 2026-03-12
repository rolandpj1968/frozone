require_relative 'node'

module Frozone
  module Ast
    class ClassVariableRead < Node
      def initialize(name)
        @name = name
      end

      def to_s = "cvar(#{@name})"

      def evaluate(context)
        klass = current_class(context)
        klass.get_class_var(@name) || Vm::NilObject::NIL
      end

      private

      def current_class(context)
        s = context.frame.the_self
        s.is_a?(Vm::ModuleObject) ? s : s.class_object
      end
    end
  end
end
