require_relative 'node'

module Frozone
  module Ast
    class Sequence < Node
      attr_reader :nodes

      def initialize(nodes)
        @nodes = nodes
      end

      def children = @nodes

      def to_s
        "seq(#{@nodes.map(&:to_s).join('; ')})"
      end

      def evaluate(context)
        result = Vm::NilObject::NIL

        @nodes.each { |n| result = n.evaluate(context) }

        result
      end
    end
  end
end
