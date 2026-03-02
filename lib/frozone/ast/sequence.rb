module Frozone
  module Ast
    class Sequence
      def initialize(nodes)
        @nodes = nodes
      end

      def to_s
        "seq(#{@nodes.map(&:to_s).join('; ')})"
      end

      def execute(context)
        result = nil

        @nodes.each do |node|
          result = node.execute(context)
        end

        result
      end
    end
  end
end
