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
        raise Vm::FrozoneException.make(:RuntimeError, "class variable access from toplevel") if klass.nil?
        val = klass.get_class_var(@name)
        raise Vm::FrozoneException.make(:NameError, "uninitialized class variable #{@name} in #{klass.name}", name: @name) if val.nil?
        val
      end

      private

      # Class variables are lexically scoped: look up from the method's defining class.
      # Fall back to the_self's class when not in a method (e.g., class body).
      def current_class(context)
        mf = context.frame.method_frame
        scope = mf&.def_scope
        # For a real class/module scope (not Object), use it directly.
        if scope.is_a?(Vm::ModuleObject) && !scope.equal?(Vm::Core::OBJECT_CLASS)
          return scope
        end
        # If self is a class/module (we're in a class body), use self.
        s = context.frame.the_self
        return s if s.is_a?(Vm::ModuleObject)
        # Otherwise, toplevel or toplevel method → RuntimeError
        nil
      end
    end
  end
end
