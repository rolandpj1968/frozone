require_relative 'node'

module Frozone
  module Ast
    class LocalVariableRead < Node
      def initialize(name, depth)
        @name = check_type("name", name, Symbol)
        @depth = check_type("depth", depth, Integer)
      end

      def to_s = "local(#{@name}, #{@depth})"

      # TODO depth
      def evaluate(context) = context.frame.get_local(@name)
    end
  end
end
