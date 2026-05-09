require_relative 'node'

module Frozone
  module Ast
    class ClassVariableRead < Node
      attr_reader :name
      def initialize(name)
        @name = name
      end

      def to_s = "cvar(#{@name})"

      def evaluate(context)
        klass = current_class(context)
        raise Vm::FrozoneException.make(:RuntimeError, "class variable access from toplevel") if klass.nil?
        # Check definedness first — a cvar explicitly assigned nil is
        # defined and reads as nil; only truly absent cvars raise.
        unless klass.class_var_defined?(@name)
          raise Vm::FrozoneException.make(:NameError, "uninitialized class variable #{@name} in #{klass.name}", name: @name).tap { |exc|
            exc.vm_object.set_ivar(:@receiver, klass)
          }
        end
        klass.get_class_var(@name)
      end

      private

      # Class variables are lexically scoped: look up from the method's defining class.
      # Fall back to the_self's class when not in a method (e.g., class body).
      # Singleton class scopes are transparent for class variables (Ruby semantics):
      # @@var inside `class << self` reads from the original class, not the singleton.
      def current_class(context)
        mf = context.frame.method_frame
        # cvar_scope is set for lambda blocks in instance_eval to preserve lexical scope
        scope = mf&.cvar_scope || mf&.def_scope
        # For a real class/module scope (not Object), use it directly.
        if scope.is_a?(Vm::ModuleObject) && !scope.equal?(Vm::Core::OBJECT_CLASS)
          # Unwrap singleton classes: @@var in `class << Foo` body → read from Foo
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
