require_relative 'node'

module Frozone
  module Ast
    class Sequence < Node
      def initialize(nodes)
        @nodes = check_array_type("nodes", nodes, Node)
      end

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
