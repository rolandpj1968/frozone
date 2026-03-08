require_relative 'node'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class MethodAlias < Node
      def initialize(new_name, old_name)
        @new_name = check_type("new_name", new_name, Vm::SymbolObject)
        @old_name = check_type("old_name", old_name, Vm::SymbolObject)
      end

      def to_s
        "alias(#{@new_name.raw}, #{@old_name.raw})"
      end

      def evaluate(context)
        #clazz = context.frame.the_self
        clazz = context.scopes.last
        # TODO - what about eigenclass? Can you alias instance methods?
        method = clazz.lookup_method(@old_name)
        # TODO this is a runtime error, not an assert
        # TODO fully-qualified class name
        raise "undefined method '#{@old_name.raw}' for class '#{clazz.name.raw}' (NameError)" if method.nil?
        clazz.set_method(@new_name, method.alias_as(@new_name))
        @new_name # TODO check empirically
      end
    end
  end
end
