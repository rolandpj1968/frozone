require_relative 'node'

module Frozone
  module Ast
    class LocalVariableRead < Node
      attr_reader :name
      def initialize(name, depth)
        @name = name
        @depth = depth
      end

      def to_s = "local(#{@name}, #{@depth})"

      def evaluate(context) = context.frame.frame_at_depth(@depth).get_local(@name)
    end
  end
end
