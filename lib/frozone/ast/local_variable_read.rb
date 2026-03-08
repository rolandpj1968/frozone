require_relative 'node'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class LocalVariableRead < Node
      def initialize(name, depth)
        @name = check_type("name", name, Vm::SymbolObject)
        @depth = check_type("depth", depth, Integer)
      end

      def to_s = "local(#{@name.raw}, #{@depth})"

      # TODO depth
      def evaluate(context) = context.frame.get_local(@name)
    end
  end
end
