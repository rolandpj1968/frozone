require_relative 'node'
require_relative '../vm/frozone_exception'
require_relative '../vm/intrinsics'

module Frozone
  module Ast
    class IntrinsicCall < Node
      def initialize(name, param_nodes)
        @method = self.class.method_for(name)
        @param_nodes = param_nodes
      end

      def children = @param_nodes

      def to_s
        # @method.owner is class's eigenclass??? - not sure how to get the Class name
        "intrinsic[#{@method.name}](#{@param_nodes.map(&:to_s).join(', ')})"
      end

      def evaluate(context)
        args = @param_nodes.flat_map do |p|
          p.is_a?(SplatArg) ? p.evaluate(context).raw : p.evaluate(context)
        end

        @method.call(context, *args)
      end

      def marshal_dump
        [@method.name, @param_nodes]
      end

      def marshal_load(data)
        name, param_nodes = data
        @method = self.class.method_for(name)
        @param_nodes = param_nodes
      end

      # TODO - thread safety
      Methods = {}

      def self.method_for(name)
        Methods[name] ||= Vm::Intrinsics.method(name)
      end
    end
  end
end
