require_relative 'node'

module Frozone
  module Ast
    class InstanceVariableRead < Node
      def initialize(name)
        @name = check_type("name", name, Symbol)
      end

      def to_s = "ivar(#{@name})"

      def evaluate(context) = context.frame.the_self.get_ivar(@name)
    end
  end
end
