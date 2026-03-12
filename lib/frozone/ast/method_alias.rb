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
        #clazz = context.frame.the_self
        clazz = context.scopes.last
        # TODO - what about eigenclass? Can you alias instance methods?
        method = clazz.is_a?(Vm::ClassObject) ? clazz.lookup_method(@old_name) : clazz.get_method(@old_name)
        # TODO this is a runtime error, not an assert
        # TODO fully-qualified class name
        raise "undefined method '#{@old_name}' for class '#{clazz.name}' (NameError)" if method.nil?
        clazz.set_method(@new_name, method.alias_as(@new_name))
        Vm::SymbolObject.from(@new_name) # TODO check empirically
      end
    end
  end
end
