require_relative 'node'

module Frozone
  module Ast
    class ClassVariableWrite < Node
      def initialize(name, value_node)
        @name = name
        @value_node = value_node
      end

      def to_s = "cvar=(#{@name}, #{@value_node})"

      def evaluate(context) = store(context, @value_node.evaluate(context))

      def store(context, value)
        klass = current_class(context)
        raise Vm::FrozoneException.make(:RuntimeError, "class variable access from toplevel") if klass.nil?
        klass.set_class_var(@name, value)
        value
      end

      private

      # Class variables are lexically scoped: look up from the method's defining class.
      # Fall back to the_self's class when not in a method (e.g., class body).
      # Singleton class scopes are transparent for class variables (Ruby semantics):
      # @@var inside `class << self` writes to the original class, not the singleton.
      def current_class(context)
        mf = context.frame.method_frame
        # cvar_scope is set for lambda blocks in instance_eval to preserve lexical scope
        scope = mf&.cvar_scope || mf&.def_scope
        # For a real class/module scope (not Object), use it directly.
        if scope.is_a?(Vm::ModuleObject) && !scope.equal?(Vm::Core::OBJECT_CLASS)
          # Unwrap singleton classes: @@var in `class << Foo` body → stored in Foo
          scope = scope.singleton_of while scope.is_a?(Vm::ModuleObject) && scope.is_singleton_class
          return scope if scope.is_a?(Vm::ModuleObject)
        end
        # If self is a class/module (we're in a class body), use self.
        s = context.frame.the_self
        if s.is_a?(Vm::ModuleObject)
          s = s.singleton_of while s.is_singleton_class
          return s
        end
        # Otherwise, toplevel or toplevel method → RuntimeError
        nil
      end
    end
  end
end
