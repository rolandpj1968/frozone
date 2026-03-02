module Frozone
  module Ast
    class MethodAlias
      def initialize(new_name, old_name)
        raise "new_name must be a Symbol" unless new_name.class.equal?(Symbol)
        raise "old_name must be a Symbol" unless old_name.class.equal?(Symbol)
        @new_name = new_name
        @old_name = old_name
      end

      def to_s
        "alias(#{@new_name}, #{old_name})"
      end

      def evaluate(context)
        #clazz = context.frame.the_self
        clazz = context.scopes.last
        # TODO - what about eigenclass? Can you alias in instance methods?
        method = clazz.lookup_method(@old_name)
        # TODO this is a runtime error, not an assert
        # TODO fully-qualified class name
        raise "undefined method '#{old_name}' for class '#{clazz.name}' (NameError) e.g." if method.nil?
        clazz.set_method(@new_name, method.alias_as(@new_name))
        Vm::SymbolObject.from(@new_name) # TODO check empirically
      end
    end
  end
end
