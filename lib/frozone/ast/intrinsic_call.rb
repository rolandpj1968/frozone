require_relative 'node'
require_relative '../vm/intrinsics'

module Frozone
  module Ast
    class IntrinsicCall < Node
      def initialize(name, param_nodes)
        @method = self.class.method_for(name)
        @param_nodes = check_array_type("param_nodes", param_nodes, Node)
      end

      def to_s
        # @method.owner is class's eigenclass??? - not sure how to get the Class name
        "intrinsic[#{@method.name}](#{@param_nodes.map(&:to_s).join(', ')})"
      end

      def evaluate(context)
        args = @param_nodes.map { |p| p.evaluate(context) }

        @method.call(*args)
      end

      # TODO - thread safety
      Methods = {}

      def self.method_for(name)
        Methods[name] ||= Vm::Intrinsics.method(name)
      end
    end
  end
end
