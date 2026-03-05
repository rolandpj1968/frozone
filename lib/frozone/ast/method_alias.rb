require_relative 'node'

module Frozone
  module Ast
    class MethodAlias < Node
      def initialize(new_name, old_name)
        @new_name = check_type("new_name", new_name, Symbol)
        @old_name = check_type("old_name", old_name, Symbol)
      end

      def to_s
        "alias(#{@new_name}, #{old_name})"
      end

      def evaluate(context)
        #clazz = context.frame.the_self
        clazz = context.scopes.last
        # TODO - what about eigenclass? Can you alias instance methods?
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
